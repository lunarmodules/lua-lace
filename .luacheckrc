codes = true

std = "lua53c"
max_line_length = 150


files["test/"] = {
    ignore = { "211/msg", "411/msg", "421/err", "212/ctx", "212/cctx" }
}

files["example/"] = {
    ignore = { "211/msg", "411/msg" }
}
