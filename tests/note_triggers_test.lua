require("../includes/note_triggers")
require("../dev/var_dump")

-- 1st
assert(is_trig_active("01", 0) == true)
assert(is_trig_active("01", 1) == false)

-- !1st
assert(is_trig_active("00", 0) == false)
assert(is_trig_active("00", 1) == true)

-- nth
assert(is_trig_active("20", 0) == false)
assert(is_trig_active("20", 1) == true)
assert(is_trig_active("20", 2) == false)
assert(is_trig_active("20", 3) == false)

-- x:y
assert(is_trig_active("42", 0) == false)
assert(is_trig_active("42", 1) == true)
assert(is_trig_active("42", 2) == false)
assert(is_trig_active("42", 3) == false)
assert(is_trig_active("42", 4) == false)
assert(is_trig_active("42", 5) == true)

-- 4:4
assert(is_trig_active("44", 0) == false)
assert(is_trig_active("44", 1) == false)
assert(is_trig_active("44", 2) == false)
assert(is_trig_active("44", 3) == true)

