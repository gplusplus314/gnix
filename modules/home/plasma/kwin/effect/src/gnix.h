#pragma once

#include <kwin/effect/effect.h>

#include <QColor>
#include <QHash>
#include <QMarginsF>
#include <QRect>
#include <QRegion>
#include <QString>

#include <chrono>
#include <memory>
#include <optional>
#include <vector>

class QFileSystemWatcher;

namespace KWin
{
class GLShader;
}

class GnixHideSpy;

class GnixEffect : public KWin::Effect
{
    Q_OBJECT
public:
    GnixEffect();
    ~GnixEffect() override;

    void prePaintScreen(KWin::ScreenPrePaintData &data,
                        std::chrono::milliseconds presentTime) override;

    void paintScreen(const KWin::RenderTarget &renderTarget,
                     const KWin::RenderViewport &viewport,
                     int mask, const KWin::Region &region,
                     KWin::LogicalOutput *screen) override;

    void reconfigure(ReconfigureFlags flags) override;

    enum class WarpAnchor {
        Center,
        TopLeft, Top, TopRight,
        Right,
        BottomRight, Bottom, BottomLeft,
        Left,
    };

    struct WarpTarget {
        WarpAnchor anchor = WarpAnchor::Center;
        double dx = 0.0;
        double dy = 0.0;
        bool skip = false;
        bool hideCursor = true;
    };

private:
    struct WindowOverride {
        QString matchWindowClass;
        QString matchWindowCaption;
        QString matchWindowType;
        QMarginsF inset;
        std::optional<float> radius;
        float width;
        QColor color;
        bool skip;
        std::optional<WarpTarget> warp;
    };

    // Style for one window with override/decoration/default precedence
    // already applied. Callers only need one findOverride lookup.
    struct ResolvedStyle {
        QMarginsF inset;
        float radius;
        float width;
        QColor color;
    };

    bool isRelevantWindow(KWin::EffectWindow *w) const;
    bool needsBorderForActive(KWin::LogicalOutput *screen,
                              KWin::EffectWindow *&activeOut) const;
    QRect borderBBox(KWin::EffectWindow *w, const ResolvedStyle &style) const;
    QRegion borderRegion(KWin::EffectWindow *w) const;
    QRegion occludersAbove(KWin::EffectWindow *w) const;
    void drawBorder(const KWin::RenderViewport &viewport,
                    KWin::EffectWindow *w) const;
    void loadShader();
    QString configPath() const;
    void rearmFileWatcher();
    void requestRepaintForActive();

    ResolvedStyle resolveStyle(KWin::EffectWindow *w) const;
    const WindowOverride *findOverride(KWin::EffectWindow *w) const;

    std::unique_ptr<KWin::GLShader> m_shader;
    QFileSystemWatcher *m_fileWatcher = nullptr;
    std::unique_ptr<GnixHideSpy> m_hideSpy;

    float m_width = 1.0f;
    float m_radius = 6.0f;
    QMarginsF m_inset{0.0, 0.0, 0.0, 0.0};
    QColor m_color{170, 0, 255};

    std::vector<WindowOverride> m_overrides;

    QHash<KWin::LogicalOutput *, QRegion> m_lastDrawnRegions;
};
