#!/usr/bin/env python3
"""Regression check: VISCERA Auth e-mails retain branding and safe HTTPS links."""
from html.parser import HTMLParser
from pathlib import Path

SITE = "https://elghalimamac-tech.github.io/VISCERA/"
LOGO = SITE + "icons/Icon-192.png"

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []
        self.logos = []
    def handle_starttag(self, tag, attrs):
        fields = dict(attrs)
        if tag == "a" and "href" in fields:
            self.urls.append(fields["href"])
        if tag == "img" and "src" in fields:
            self.logos.append(fields)

for filename, kind in [
    ("confirmation.html", "signup"),
    ("recovery.html", "recovery"),
]:
    source = Path("emails", filename).read_text(encoding="utf-8")
    html = Links()
    html.feed(source)
    expected = SITE + "#token_hash={{ .TokenHash }}&type=" + kind
    assert any(item["src"] == LOGO and "VISCERA" in item.get("alt", "")
               for item in html.logos), f"{filename}: missing official PNG logo"
    assert len(html.urls) >= 2, f"{filename}: missing button or fallback"
    assert all(url == expected for url in html.urls), (
        f"{filename}: unexpected authentication URL"
    )
    assert "VISCERA" in source and "<table" in source, (
        f"{filename}: missing responsive e-mail layout"
    )
    print(f"{filename}: logo and secure links verified")
