import pytest

pytestmark = pytest.mark.django_db


@pytest.mark.parametrize("url,label", [("/", "Overview"), ("/work/?month=2026-09", "Work"), ("/money/", "Money"), ("/habits/", "Habits")])
def test_shell_has_one_main_and_current_destination(client, url, label):
    from html.parser import HTMLParser

    class Landmarks(HTMLParser):
        mains = 0
        headings = 0
        current = None
        collecting = False

        def handle_starttag(self, tag, attrs):
            attrs = dict(attrs)
            self.mains += tag == "main"
            self.headings += tag == "h1"
            if tag == "a" and attrs.get("aria-current") == "page":
                self.collecting = True
                self.current = ""

        def handle_data(self, data):
            if self.collecting:
                self.current += data

        def handle_endtag(self, tag):
            if tag == "a":
                self.collecting = False

    parsed = Landmarks()
    parsed.feed(client.get(url).content.decode())
    assert parsed.mains == parsed.headings == 1
    assert parsed.current == label
