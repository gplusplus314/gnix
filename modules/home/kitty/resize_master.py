from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    direction = args[1] if len(args) > 1 else "grow"
    step = 0.05
    delta = step if direction == "grow" else -step

    tab = boss.active_tab
    if tab is None:
        return
    layout = tab.current_layout
    if layout is None or getattr(layout, "name", None) != "tall":
        return
    if not hasattr(layout, "apply_bias"):
        return

    if layout.apply_bias(0, delta, tab.windows, is_horizontal=True):
        tab.relayout()
