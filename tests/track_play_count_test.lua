require("../includes/track_play_count")
require("../dev/var_dump")
require("../dev/assertions")

-- Identical lengths:
assert_dictionary(
    get_track_play_count(0, 16, {
        [1] = 16,
        [2] = 16,
        [3] = 16,
        [4] = 16
    }), 
    {
        [1] = 0, 
        [2] = 0, 
        [3] = 0, 
        [4] = 0
    }
)

assert_dictionary(
    get_track_play_count(1, 16, {
        [1] = 16,
        [2] = 16,
        [3] = 16,
        [4] = 16
    }), 
    {
        [1] = 1, 
        [2] = 1, 
        [3] = 1, 
        [4] = 1
    }
)

-- Different lengths:
assert_dictionary(
    get_track_play_count(0, 16, {
        [1] = 16,
        [2] = 4,
        [3] = 8,
        [4] = 16
    }), 
    {
        [1] = 0, 
        [2] = 0, 
        [3] = 0, 
        [4] = 0
    }
)

assert_dictionary(
    get_track_play_count(1, 16, {
        [1] = 16,
        [2] = 4,
        [3] = 8,
        [4] = 16
    }), 
    {
        [1] = 1, 
        [2] = 4, 
        [3] = 2, 
        [4] = 1
    }
)

assert_dictionary(
    get_track_play_count(4, 16, {
        [1] = 16,
        [2] = 4,
        [3] = 8,
        [4] = 16
    }), 
    {
        [1] = 4, 
        [2] = 16, 
        [3] = 8, 
        [4] = 4
    }
)

-- Polyrhytm (count only includes full lengths):
assert_dictionary(
    get_track_play_count(0, 16, {
        [1] = 16,
        [2] = 3,
        [3] = 6,
        [4] = 7
    }), 
    {
        [1] = 0, 
        [2] = 0, 
        [3] = 0, 
        [4] = 0
    }
)

assert_dictionary(
    get_track_play_count(1, 16, {
        [1] = 16,
        [2] = 3,
        [3] = 6,
        [4] = 7
    }), 
    {
        [1] = 1, 
        [2] = 5, 
        [3] = 2, 
        [4] = 2
    }
)

assert_dictionary(
    get_track_play_count(4, 16, {
        [1] = 16,
        [2] = 3,
        [3] = 6,
        [4] = 7
    }), 
    {
        [1] = 4, 
        [2] = 21, 
        [3] = 10, 
        [4] = 9
    }
)
