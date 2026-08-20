#include "gnix.h"

#include <kwin/cursor.h>
#include <kwin/effect/effecthandler.h>
#include <kwin/effect/effectwindow.h>
#include <kwin/core/output.h>
#include <kwin/core/renderviewport.h>
#include <kwin/input.h>
#include <kwin/input_event.h>
#include <kwin/input_event_spy.h>
#include <kwin/opengl/glvertexbuffer.h>
#include <kwin/opengl/glshadermanager.h>
#include <kwin/opengl/glshader.h>
#include <kwin/opengl/eglcontext.h>
#include <kwin/wayland/layershell_v1.h>
#include <kwin/wayland/surface.h>

#include <KDecoration3/Decoration>

#include <QByteArray>
#include <QCursor>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QPoint>
#include <QRectF>
#include <QRegion>
#include <QStandardPaths>
#include <QStringList>
#include <QVector2D>
#include <cmath>
#include <vector>

namespace KWin
{
KWIN_EFFECT_FACTORY_SUPPORTED(GnixEffect,
                               "metadata.json",
                               return effects->isOpenGLCompositing();)
}

class GnixHideSpy : public KWin::InputEventSpy
{
public:
    void pointerMotion(KWin::PointerMotionEvent *event) override
    {
        if (event->warp) return;
        stamp();
        release();
    }
    void pointerButton(KWin::PointerButtonEvent *) override
    {
        stamp();
        release();
    }
    void pointerAxis(KWin::PointerAxisEvent *) override
    {
        stamp();
        release();
    }

    void hold()
    {
        if (m_holding) return;
        m_holding = true;
        KWin::Cursors::self()->hideCursor();
    }

    void release()
    {
        if (!m_holding) return;
        m_holding = false;
        KWin::Cursors::self()->showCursor();
    }

    bool hadRecentInput(std::chrono::milliseconds within) const
    {
        if (m_lastInput.time_since_epoch().count() == 0) return false;
        return (std::chrono::steady_clock::now() - m_lastInput) <= within;
    }

    ~GnixHideSpy() override { release(); }

private:
    void stamp() { m_lastInput = std::chrono::steady_clock::now(); }

    bool m_holding = false;
    std::chrono::steady_clock::time_point m_lastInput{};
};

namespace
{
std::optional<GnixEffect::WarpAnchor> anchorFromString(const QString &s)
{
    static const QHash<QString, GnixEffect::WarpAnchor> kAnchors = {
        {QStringLiteral("center"),      GnixEffect::WarpAnchor::Center},
        {QStringLiteral("topleft"),     GnixEffect::WarpAnchor::TopLeft},
        {QStringLiteral("top"),         GnixEffect::WarpAnchor::Top},
        {QStringLiteral("topright"),    GnixEffect::WarpAnchor::TopRight},
        {QStringLiteral("right"),       GnixEffect::WarpAnchor::Right},
        {QStringLiteral("bottomright"), GnixEffect::WarpAnchor::BottomRight},
        {QStringLiteral("bottom"),      GnixEffect::WarpAnchor::Bottom},
        {QStringLiteral("bottomleft"),  GnixEffect::WarpAnchor::BottomLeft},
        {QStringLiteral("left"),        GnixEffect::WarpAnchor::Left},
    };
    const auto it = kAnchors.constFind(s.toLower());
    if (it == kAnchors.cend()) return std::nullopt;
    return *it;
}

QPointF anchorPoint(const QRectF &frame, GnixEffect::WarpAnchor a)
{
    // QRectF::right()/bottom() are x+w / y+h, i.e. one past the last pixel.
    // Clamp to the last visible row/column when anchoring to an edge.
    const double l = frame.left();
    const double t = frame.top();
    const double r = frame.right() - 1.0;
    const double b = frame.bottom() - 1.0;
    const double cx = frame.center().x();
    const double cy = frame.center().y();
    using A = GnixEffect::WarpAnchor;
    switch (a) {
    case A::Center:      return {cx, cy};
    case A::TopLeft:     return {l,  t};
    case A::Top:         return {cx, t};
    case A::TopRight:    return {r,  t};
    case A::Right:       return {r,  cy};
    case A::BottomRight: return {r,  b};
    case A::Bottom:      return {cx, b};
    case A::BottomLeft:  return {l,  b};
    case A::Left:        return {l,  cy};
    }
    return frame.center();
}

bool windowMatchesType(KWin::EffectWindow *w, const QString &typeLower)
{
    if (typeLower.isEmpty()) return true;

    if (typeLower == QLatin1String("layershell")) {
        auto *s = w->surface();
        return s && s->role() == KWin::LayerSurfaceV1Interface::role();
    }

    static const QHash<QString, QByteArray> kTypeProperty = {
        {QStringLiteral("normal"),               QByteArrayLiteral("normalWindow")},
        {QStringLiteral("dialog"),               QByteArrayLiteral("dialog")},
        {QStringLiteral("popup"),                QByteArrayLiteral("popupWindow")},
        {QStringLiteral("popupmenu"),            QByteArrayLiteral("popupMenu")},
        {QStringLiteral("dropdownmenu"),         QByteArrayLiteral("dropdownMenu")},
        {QStringLiteral("combobox"),             QByteArrayLiteral("comboBox")},
        {QStringLiteral("tooltip"),              QByteArrayLiteral("tooltip")},
        {QStringLiteral("splash"),               QByteArrayLiteral("splash")},
        {QStringLiteral("utility"),              QByteArrayLiteral("utility")},
        {QStringLiteral("notification"),         QByteArrayLiteral("notification")},
        {QStringLiteral("criticalnotification"), QByteArrayLiteral("criticalNotification")},
        {QStringLiteral("onscreendisplay"),      QByteArrayLiteral("onScreenDisplay")},
        {QStringLiteral("dock"),                 QByteArrayLiteral("dock")},
        {QStringLiteral("desktop"),              QByteArrayLiteral("desktopWindow")},
        {QStringLiteral("menu"),                 QByteArrayLiteral("menu")},
        {QStringLiteral("toolbar"),              QByteArrayLiteral("toolbar")},
        {QStringLiteral("dndicon"),              QByteArrayLiteral("dndIcon")},
    };
    const auto it = kTypeProperty.constFind(typeLower);
    if (it == kTypeProperty.cend()) return false;
    return w->property(it.value().constData()).toBool();
}
} // namespace

GnixEffect::GnixEffect()
{
    connect(KWin::effects, &KWin::EffectsHandler::windowActivated,
            this, [this](KWin::EffectWindow *) {
        requestRepaintForActive();
    });
    connect(KWin::effects, &KWin::EffectsHandler::windowAdded,
            this, [this](KWin::EffectWindow *) {
        requestRepaintForActive();
    });
    connect(KWin::effects, &KWin::EffectsHandler::windowClosed,
            this, [this](KWin::EffectWindow *) {
        requestRepaintForActive();
    });
    connect(KWin::effects, &KWin::EffectsHandler::windowDeleted,
            this, [this](KWin::EffectWindow *) {
        requestRepaintForActive();
    });
    connect(KWin::effects, &KWin::EffectsHandler::stackingOrderChanged,
            this, [this]() {
        requestRepaintForActive();
    });

    connect(KWin::effects, &KWin::EffectsHandler::screenRemoved,
            this, [this](KWin::LogicalOutput *o) {
        m_lastDrawnRegions.remove(o);
    });
    connect(KWin::effects, &KWin::EffectsHandler::screenAdded,
            this, [this](KWin::LogicalOutput *o) {
        m_lastDrawnRegions.remove(o);
    });

    m_hideSpy = std::make_unique<GnixHideSpy>();
    KWin::input()->installInputEventSpy(m_hideSpy.get());

    connect(KWin::effects, &KWin::EffectsHandler::windowActivated,
            this, [this](KWin::EffectWindow *w) {
        if (KWin::effects->isScreenLocked()) return;
        if (!w) return;
        // Only warp non-toplevel surfaces (layer-shell, popups, OSDs) when an
        // explicit warp override matches them. Transient layer-shells like
        // the screen locker shouldn't warp just by appearing.
        if (!w->isNormalWindow() && !w->isDialog()) {
            auto *o = findOverride(w);
            if (!o || !o->warp) return;
        }
        const QRectF geo = w->frameGeometry();
        if (geo.isEmpty()) return;

        WarpTarget warpCfg;
        if (auto *o = findOverride(w); o && o->warp) {
            if (o->warp->skip) return;
            warpCfg = *o->warp;
        }
        const QPoint target = (anchorPoint(geo, warpCfg.anchor)
                               + QPointF(warpCfg.dx, warpCfg.dy)).toPoint();
        const QPoint current = QCursor::pos();
        if (current == target) return;
        // If the focus change followed a real pointer event and the cursor
        // is already inside the new frame, a click activated the window.
        // Don't yank the cursor away from where the user just clicked.
        if (geo.contains(current)
            && m_hideSpy->hadRecentInput(std::chrono::milliseconds(150))) {
            return;
        }

        // setPos and hideCursor re-enter KWin's cursor/input pipeline, and
        // doing that from inside the activation signal re-enters the window
        // transaction that's still in flight, so defer them.
        const bool hide = warpCfg.hideCursor;
        QMetaObject::invokeMethod(this, [this, target, hide]() {
            if (KWin::effects->isScreenLocked()) return;
            QCursor::setPos(target);
            // Spy releases on the next real pointer event.
            if (hide) m_hideSpy->hold();
        }, Qt::QueuedConnection);
    });

    loadShader();

    m_fileWatcher = new QFileSystemWatcher(this);
    auto onChange = [this]() {
        reconfigure(ReconfigureAll);
        rearmFileWatcher();
    };
    connect(m_fileWatcher, &QFileSystemWatcher::fileChanged, this, onChange);
    connect(m_fileWatcher, &QFileSystemWatcher::directoryChanged, this, onChange);

    rearmFileWatcher();
    reconfigure(ReconfigureAll);
}

QString GnixEffect::configPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
           + QStringLiteral("/gnix/kwin_effects.json");
}

void GnixEffect::rearmFileWatcher()
{
    const QString path = configPath();
    const QString dir = QFileInfo(path).absolutePath();
    const QStringList files = m_fileWatcher->files();
    const QStringList dirs = m_fileWatcher->directories();
    if (!files.contains(path) && QFileInfo::exists(path)) {
        m_fileWatcher->addPath(path);
    }
    if (!dirs.contains(dir) && QFileInfo::exists(dir)) {
        m_fileWatcher->addPath(dir);
    }
}

void GnixEffect::requestRepaintForActive()
{
    QRegion r;
    for (const QRegion &region : m_lastDrawnRegions) {
        if (!region.isEmpty()) r += region;
    }
    if (auto *a = KWin::effects->activeWindow(); a && isRelevantWindow(a)) {
        r += borderRegion(a);
    }
    if (!r.isEmpty()) {
        KWin::effects->addRepaint(KWin::Region(r));
    }
}

GnixEffect::~GnixEffect()
{
    // KWin keeps a raw pointer to the installed spy. Uninstall it before the
    // unique_ptr frees it, or the next dispatched pointer event is a
    // use-after-free.
    if (m_hideSpy) {
        KWin::input()->uninstallInputEventSpy(m_hideSpy.get());
    }
}

void GnixEffect::loadShader()
{
    QFile vf(QStringLiteral(":/effects/gnix/windowborder.vert"));
    QFile ff(QStringLiteral(":/effects/gnix/windowborder.frag"));
    if (!vf.open(QIODevice::ReadOnly) || !ff.open(QIODevice::ReadOnly)) {
        qWarning() << "gnix: failed to open border shader resources";
        return;
    }

    QByteArray header;
    if (auto *ctx = KWin::EglContext::currentContext(); ctx && ctx->isOpenGLES()) {
        header = QByteArrayLiteral("#version 320 es\n\nprecision highp float;\n\n");
    } else {
        header = QByteArrayLiteral("#version 140\n\n");
    }

    m_shader = KWin::ShaderManager::instance()->loadShaderFromCode(
        header + vf.readAll(),
        header + ff.readAll());
    if (!m_shader || !m_shader->isValid()) {
        qWarning() << "gnix: border shader failed to compile";
    }
}

void GnixEffect::reconfigure(ReconfigureFlags /*flags*/)
{
    auto parseColor = [](const QJsonValue &v, const QColor &fallback) {
        if (!v.isString()) return fallback;
        const QString s = v.toString().trimmed();
        if (s.startsWith(QLatin1Char('#'))) {
            QColor c(s);
            return c.isValid() ? c : fallback;
        }
        const QStringList parts = s.split(QLatin1Char(','));
        if (parts.size() < 3) return fallback;
        const int r = parts[0].trimmed().toInt();
        const int g = parts[1].trimmed().toInt();
        const int b = parts[2].trimmed().toInt();
        const int a = parts.size() >= 4 ? parts[3].trimmed().toInt() : 255;
        return QColor(r, g, b, a);
    };

    auto readNumber = [](const QJsonValue &v, double fallback) {
        return v.isDouble() ? v.toDouble() : fallback;
    };

    auto readString = [](const QJsonValue &v) {
        return v.isString() ? v.toString() : QString();
    };

    auto readOptFloat = [](const QJsonValue &v) -> std::optional<float> {
        if (!v.isDouble()) return std::nullopt;
        return static_cast<float>(v.toDouble());
    };

    auto parseWarp = [&](const QJsonValue &v) -> std::optional<WarpTarget> {
        if (v.isUndefined() || v.isNull()) return std::nullopt;
        if (v.isString()) {
            const QString s = v.toString().toLower();
            WarpTarget t;
            if (s == QLatin1String("skip") || s == QLatin1String("none")
                || s == QLatin1String("off")) {
                t.skip = true;
                return t;
            }
            if (auto a = anchorFromString(s)) {
                t.anchor = *a;
                return t;
            }
            return std::nullopt;
        }
        if (v.isObject()) {
            const QJsonObject o = v.toObject();
            WarpTarget t;
            if (o.value(QStringLiteral("skip")).toBool(false)) {
                t.skip = true;
                return t;
            }
            if (auto a = anchorFromString(o.value(QStringLiteral("anchor")).toString())) {
                t.anchor = *a;
            }
            t.dx = readNumber(o.value(QStringLiteral("dx")), 0.0);
            t.dy = readNumber(o.value(QStringLiteral("dy")), 0.0);
            t.hideCursor = o.value(QStringLiteral("hideCursor")).toBool(true);
            return t;
        }
        return std::nullopt;
    };

    auto readInset = [&](const QJsonObject &o, const QMarginsF &fallback) {
        QMarginsF m = fallback;
        if (o.contains(QStringLiteral("inset"))) {
            const double v = readNumber(o.value(QStringLiteral("inset")), 0.0);
            m = QMarginsF(v, v, v, v);
        }
        m.setLeft  (readNumber(o.value(QStringLiteral("insetLeft")),   m.left()));
        m.setTop   (readNumber(o.value(QStringLiteral("insetTop")),    m.top()));
        m.setRight (readNumber(o.value(QStringLiteral("insetRight")),  m.right()));
        m.setBottom(readNumber(o.value(QStringLiteral("insetBottom")), m.bottom()));
        return m;
    };

    QFile f(configPath());
    QJsonObject root;
    if (f.open(QIODevice::ReadOnly)) {
        QJsonParseError err{};
        const auto doc = QJsonDocument::fromJson(f.readAll(), &err);
        if (err.error == QJsonParseError::NoError && doc.isObject()) {
            root = doc.object();
        } else {
            qWarning() << "gnix: ignoring config" << f.fileName() << "-"
                       << (err.error != QJsonParseError::NoError
                               ? err.errorString()
                               : QStringLiteral("root is not an object"));
        }
    }

    const QJsonObject defaults = root.value(QStringLiteral("defaults")).toObject();
    m_width  = static_cast<float>(readNumber(defaults.value(QStringLiteral("width")), 1.0));
    m_radius = static_cast<float>(readNumber(defaults.value(QStringLiteral("radius")), 6.0));
    m_inset  = readInset(defaults, QMarginsF(0.0, 0.0, 0.0, 0.0));
    m_color  = parseColor(defaults.value(QStringLiteral("color")), QColor(170, 0, 255));

    m_overrides.clear();
    const QJsonArray overrides = root.value(QStringLiteral("overrides")).toArray();
    m_overrides.reserve(overrides.size());
    for (const QJsonValue &entry : overrides) {
        if (!entry.isObject()) continue;
        const QJsonObject o = entry.toObject();
        const QJsonObject match = o.value(QStringLiteral("match")).toObject();
        m_overrides.push_back({
            readString(match.value(QStringLiteral("windowClass"))).toLower(),
            readString(match.value(QStringLiteral("windowCaption"))).toLower(),
            readString(match.value(QStringLiteral("windowType"))).toLower(),
            readInset(o, m_inset),
            readOptFloat(o.value(QStringLiteral("radius"))),
            static_cast<float>(readNumber(o.value(QStringLiteral("width")),  m_width)),
            parseColor(o.value(QStringLiteral("color")), m_color),
            o.value(QStringLiteral("skip")).toBool(false),
            parseWarp(o.value(QStringLiteral("warp"))),
        });
    }

    KWin::effects->addRepaintFull();
}

bool GnixEffect::isRelevantWindow(KWin::EffectWindow *w) const
{
    if (!w->isOnCurrentDesktop()) return false;
    if (w->isMinimized()) return false;
    if (w->isDesktop() || w->isDock()) return false;
    if (w->isNormalWindow() || w->isDialog()) return true;
    // Non-toplevel surfaces (layer-shell, popups, OSDs) only qualify when an
    // explicit user override matches them.
    return findOverride(w) != nullptr;
}

const GnixEffect::WindowOverride *
GnixEffect::findOverride(KWin::EffectWindow *w) const
{
    const QString cls = w->windowClass().toLower();
    const QStringList clsParts = cls.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    const QString caption = w->caption().toLower();

    for (const WindowOverride &o : m_overrides) {
        if (!o.matchWindowClass.isEmpty()
            && o.matchWindowClass != cls
            && !clsParts.contains(o.matchWindowClass)) {
            continue;
        }
        if (!o.matchWindowCaption.isEmpty() && o.matchWindowCaption != caption) {
            continue;
        }
        if (!o.matchWindowType.isEmpty() && !windowMatchesType(w, o.matchWindowType)) {
            continue;
        }
        return &o;
    }
    return nullptr;
}

GnixEffect::ResolvedStyle GnixEffect::resolveStyle(KWin::EffectWindow *w) const
{
    const WindowOverride *o = findOverride(w);

    // Radius precedence: configured override, then the decoration's own
    // rounding for decorated windows, then the default.
    float radius;
    if (o && o->radius) {
        radius = *o->radius;
    } else if (auto *deco = w->decoration()) {
        const auto r = deco->borderRadius();
        radius = static_cast<float>(std::max({
            r.topLeft(), r.topRight(), r.bottomRight(), r.bottomLeft(),
        }));
    } else {
        radius = m_radius;
    }

    if (o) return {o->inset, radius, o->width, o->color};
    return {m_inset, radius, m_width, m_color};
}

bool GnixEffect::needsBorderForActive(KWin::LogicalOutput *screen,
                                              KWin::EffectWindow *&activeOut) const
{
    activeOut = KWin::effects->activeWindow();
    if (!activeOut) return false;
    if (activeOut->screen() != screen) return false;
    if (!isRelevantWindow(activeOut)) return false;
    if (auto *o = findOverride(activeOut); o && o->skip) return false;

    // A non-toplevel surface can only get here by matching an override
    // (isRelevantWindow gates that), so always draw it.
    if (!activeOut->isNormalWindow() && !activeOut->isDialog()) {
        return true;
    }

    int windowCount = 0;
    for (KWin::EffectWindow *w : KWin::effects->stackingOrder()) {
        if (w->screen() != screen) continue;
        if (!isRelevantWindow(w)) continue;
        if ((w->isNormalWindow() || w->isDialog()) && ++windowCount > 1) break;
    }
    return windowCount > 1;
}

QRect GnixEffect::borderBBox(KWin::EffectWindow *w, const ResolvedStyle &style) const
{
    const float pad = style.width + style.radius + 1.0f;
    return w->frameGeometry()
        .marginsRemoved(style.inset)
        .adjusted(-pad, -pad, pad, pad)
        .toAlignedRect();
}

QRegion GnixEffect::borderRegion(KWin::EffectWindow *w) const
{
    const ResolvedStyle style = resolveStyle(w);
    const QRect bbox = borderBBox(w, style);
    // Matches the band/corner footprint of the quads in drawBorder. Taking
    // the max keeps the inset safe for any (radius, width) combination.
    const float safe = std::max(style.radius, style.width) + 1.0f;
    const QRectF frame = w->frameGeometry().marginsRemoved(style.inset);
    const QRectF inner = frame.adjusted(safe, safe, -safe, -safe);
    QRegion r(bbox);
    if (inner.width() > 0.0 && inner.height() > 0.0) {
        r -= inner.toAlignedRect();
    }
    return r;
}

QRegion GnixEffect::occludersAbove(KWin::EffectWindow *w) const
{
    // The border draws as a screen overlay after all windows are composited,
    // so anything stacked above the active window has to clip it. Skipping
    // this bleeds the border on top of popups and dialogs sitting over the
    // window.
    QRegion occluded;
    bool above = false;
    for (KWin::EffectWindow *other : KWin::effects->stackingOrder()) {
        if (other == w) {
            above = true;
            continue;
        }
        if (!above) continue;
        if (other->screen() != w->screen()) continue;
        if (other->isDesktop()) continue;
        // An auto-hiding panel keeps a full-size surface while dodged off
        // the active area, and KWin marks it hidden. Checking isHidden()
        // stops an off-screen dock from clipping the border while a shown
        // dock still occludes.
        if (!other->isVisible() || other->isHidden() || other->isMinimized())
            continue;
        if (other->opacity() <= 0.0) continue;
        const QRect g = other->frameGeometry().toAlignedRect();
        if (!g.isEmpty()) occluded += g;
    }
    return occluded;
}

void GnixEffect::prePaintScreen(KWin::ScreenPrePaintData &data,
                                        std::chrono::milliseconds presentTime)
{
    KWin::EffectWindow *active = nullptr;
    const bool need = needsBorderForActive(data.screen, active);

    const QRegion current = (need && active) ? borderRegion(active) : QRegion();
    const QRegion prev = m_lastDrawnRegions.value(data.screen);
    // Always recomposite under the live border ring so the alpha-blended
    // draw lands on fresh pixels. If we don't, small damage regions (cursor
    // blink) re-blend the AA edge onto itself each frame and the color
    // accumulates. Include the previous ring too when it differs, to clear
    // the trail left by a move/resize/disappearance. A ring rather than the
    // full bbox keeps the window interior on KWin's normal damage tracking.
    if (!current.isEmpty()) data.paint += KWin::Region(current);
    if (!prev.isEmpty() && prev != current) data.paint += KWin::Region(prev);
    KWin::effects->prePaintScreen(data, presentTime);
}

void GnixEffect::paintScreen(const KWin::RenderTarget &renderTarget,
                                     const KWin::RenderViewport &viewport,
                                     int mask, const KWin::Region &region,
                                     KWin::LogicalOutput *screen)
{
    if (KWin::effects->isScreenLocked()) {
        KWin::effects->paintScreen(renderTarget, viewport, mask, region, screen);
        return;
    }

    KWin::effects->paintScreen(renderTarget, viewport, mask, region, screen);

    if (!m_shader || !m_shader->isValid()) return;

    KWin::EffectWindow *active = nullptr;
    const bool need = needsBorderForActive(screen, active);

    if (need && active) {
        drawBorder(viewport, active);
        m_lastDrawnRegions[screen] = borderRegion(active);
    } else {
        m_lastDrawnRegions[screen] = QRegion();
    }
}

void GnixEffect::drawBorder(const KWin::RenderViewport &viewport,
                                    KWin::EffectWindow *w) const
{
    const float scale = static_cast<float>(viewport.scale());
    const ResolvedStyle style = resolveStyle(w);

    const QRectF frame = w->frameGeometry().marginsRemoved(style.inset);
    if (frame.width() <= 0 || frame.height() <= 0) return;

    const float borderThickness = roundf(style.width * scale);
    const float radius = style.radius * scale;

    const float left   = floorf(static_cast<float>(frame.x()) * scale);
    const float top    = floorf(static_cast<float>(frame.y()) * scale);
    const float right  = ceilf(static_cast<float>(frame.x() + frame.width()) * scale);
    const float bottom = ceilf(static_cast<float>(frame.y() + frame.height()) * scale);

    const float halfW = 0.5f * (right - left);
    const float halfH = 0.5f * (bottom - top);
    const float cx = left + halfW;
    const float cy = top + halfH;

    const float band = borderThickness + 1.0f;
    const float corner = radius + 1.0f;
    const float frameW = right - left;
    const float frameH = bottom - top;
    const float minDim = 2.0f * corner;

    std::vector<QVector2D> verts;
    auto pushQuad = [&](float xl, float yt, float xr, float yb) {
        verts.push_back({xl, yt});
        verts.push_back({xr, yt});
        verts.push_back({xr, yb});
        verts.push_back({xl, yt});
        verts.push_back({xr, yb});
        verts.push_back({xl, yb});
    };

    if (frameW <= minDim || frameH <= minDim) {
        const float qLeft   = left   - band;
        const float qTop    = top    - band;
        const float qRight  = right  + band;
        const float qBottom = bottom + band;
        verts.reserve(6);
        pushQuad(qLeft, qTop, qRight, qBottom);
    } else {
        const float qLeft   = left   - band;
        const float qRight  = right  + band;
        const float qTop    = top    - band;
        const float qBottom = bottom + band;
        const float topInner    = top    + corner;
        const float bottomInner = bottom - corner;
        const float leftInner   = left   + 1.0f;
        const float rightInner  = right  - 1.0f;

        verts.reserve(24);
        pushQuad(qLeft, qTop, qRight, topInner);
        pushQuad(qLeft, bottomInner, qRight, qBottom);
        pushQuad(qLeft, topInner, leftInner, bottomInner);
        pushQuad(rightInner, topInner, qRight, bottomInner);
    }

    KWin::ShaderBinder binder(m_shader.get());
    KWin::GLShader *s = m_shader.get();

    s->setUniform(KWin::GLShader::Mat4Uniform::ModelViewProjectionMatrix,
                  viewport.projectionMatrix());
    s->setUniform("windowCenter", QVector2D(cx, cy));
    s->setUniform("windowHalfSize", QVector2D(halfW, halfH));
    s->setUniform("borderThickness", borderThickness);
    s->setUniform("radius", radius);
    const QColor c = style.color;
    s->setUniform("color", QVector4D(
        c.redF(),
        c.greenF(),
        c.blueF(),
        c.alphaF()));

    KWin::GLVertexBuffer *vbo = KWin::GLVertexBuffer::streamingBuffer();
    vbo->setVertices(verts);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    const QRegion occluded = occludersAbove(w);
    if (occluded.isEmpty()) {
        vbo->render(GL_TRIANGLES);
    } else {
        const QRegion visible = borderRegion(w) - occluded;
        glEnable(GL_SCISSOR_TEST);
        vbo->render(viewport.mapToRenderTarget(KWin::Region(visible)),
                    GL_TRIANGLES, /*hardwareClipping=*/true);
        glDisable(GL_SCISSOR_TEST);
    }
    glDisable(GL_BLEND);
}

#include "gnix.moc"
