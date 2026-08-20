"""Copy the last command and its output to the system clipboard."""

from kittens.tui.handler import result_handler
from kitty.clipboard import set_clipboard_string
from kitty.window import CommandOutput


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    output = (
        window.cmd_output(
            CommandOutput.last_run, as_ansi=False, add_wrap_markers=False
        )
        or ""
    ).rstrip("\n")

    if not output:
        return

    full = window.as_text(add_history=True, add_wrap_markers=False).rstrip("\n")
    idx = full.rfind(output)
    if idx == -1:
        set_clipboard_string(output)
        return

    # idx is the first char of output; the line immediately above it is the
    # prompt + command line. Grab from the start of that line through end of output.
    end_of_cmd_line = max(idx - 1, 0)
    nl_before_cmd = full.rfind("\n", 0, end_of_cmd_line)
    cmd_start = 0 if nl_before_cmd == -1 else nl_before_cmd + 1
    payload = full[cmd_start : idx + len(output)]

    set_clipboard_string(payload)
