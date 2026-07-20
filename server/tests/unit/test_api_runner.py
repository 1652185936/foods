from ordin.api.run import _is_loopback_host


def test_loopback_host_detection_rejects_wildcard_and_lan_bindings() -> None:
    assert _is_loopback_host("127.0.0.1")
    assert _is_loopback_host("::1")
    assert _is_loopback_host("localhost")
    assert not _is_loopback_host("0.0.0.0")
    assert not _is_loopback_host("::")
    assert not _is_loopback_host("192.168.1.10")
