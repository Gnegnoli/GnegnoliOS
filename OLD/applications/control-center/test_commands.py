from commands import which


def test_which_finds_existing_binary():
    assert which("ls") == "ls"


def test_which_falls_back_through_candidates():
    assert which("definitely-not-a-real-binary-xyz", "ls") == "ls"


def test_which_returns_none_when_nothing_found():
    assert which("definitely-not-a-real-binary-xyz") is None


if __name__ == "__main__":
    test_which_finds_existing_binary()
    test_which_falls_back_through_candidates()
    test_which_returns_none_when_nothing_found()
    print("OK")
