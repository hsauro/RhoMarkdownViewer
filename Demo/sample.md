# Rho Markdown Viewer

This paragraph exercises **bold**, *italic*, ***bold italic***, ~~strikethrough~~,
`inline code`, ==highlighted text==, and a [link to somewhere](https://example.com/).
Nested emphasis: **bold with _italic_ inside**, and a [**bold link**](https://example.com/).

Water is H~2~O and energy is E = mc^2^. Emoji shortcodes: :smile: :warning: :check:

Multi-character super/subscripts must shift too, not just single ones:
glucose is C~6~H~12~O~6~, rust is Fe~2~O~3~, and x^10^ + y^abc^ = z^2^.

A hard line break follows this line.\
This should be on its own line in the same paragraph.

Entities decode: &copy; 2024 &mdash; 100&nbsp;&times;&nbsp;200, &#169;, &#x20AC;

Escaped punctuation stays literal: \*not italic\* and \[not a link\]

## Headings carry an underline rule

### H3 has no rule

#### H4 is smaller still

---

## Lists

- First bullet
- Second bullet with **emphasis**
  - Nested child
    - Grandchild
- Back to top level

1. Ordered one
2. Ordered two
3. Ordered three

Markers wider than the gutter must still keep a gap before the text, and every
period should line up:

8. Single digit
9. Single digit
10. Two digits — this butted straight against the text before the fix
11. Two digits
100. Three digits spill left of the gutter, as a browser does

- [x] Completed task
- [ ] Outstanding task
- [x] Another done one

List items are containers: a blank-separated, indented block stays inside the item.

- first paragraph of an item

  second paragraph of the same item

- item with a code block:

  ```pascal
  WriteLn('nested in the item');
  ```

- back to a plain item

## Block quote

> A quote renders with a bar down its left edge.
> It can contain **bold** and `code` too.

Quotes are containers, so they nest and hold other blocks:

> outer quote
>> inner quote nests, with a second bar

> - a list works inside a quote
> - second item
>
> and so does a paragraph after it.

## Code

```pascal
procedure Greet(const AName: string);
begin
  // A comment, and a string literal
  WriteLn('Hello, ' + AName + '!');
  if AName = '' then
    raise Exception.Create('empty');
end;
```

```python
def greet(name):
    """Docstring here."""
    if not name:
        raise ValueError("empty")
    print(f"Hello, {name}!")   # comment
```

```
Fenced block with no language tag - should render plain.
```

A longer fence carries shorter ones verbatim - the only way to show code in a
language that uses ``` itself, such as an Antimony or Python triple-quoted
string. Everything between the outer ```` fences below is one code block:

````antimony
model notes ```
This model reproduces figure 3 of the paper.
```

  J0: $Xo -> S1; k1*Xo
end
````

A tilde fence is the other escape hatch, and is closed only by tildes:

~~~text
``` and ```` both survive in here
~~~

Four-space indented code block (no fence), line breaks preserved:

    procedure Indented;
    begin
      WriteLn('lines should be preserved');
    end;

## Autolinks and references

Bare URL: https://www.embarcadero.com/ and angle form <https://docwiki.embarcadero.com/>
plus an email <support@example.com>.

A reference-style [DocWiki][docwiki] link.

[docwiki]: https://docwiki.embarcadero.com/

## Tables and images

Tables size their columns to content and squeeze proportionally when too wide.
Images scale down to the content width but are never upscaled; a missing or
remote image falls back to italic alt text.

| Header One | Header Two | Center | Right |
| :--- | :--- | :---: | ---: |
| Left data | Sample A | Centered | $100.00 |
| **Bold** | `code` | ~~old~~ | $2.50 |

![Alt text for a missing image](images/example.png)

An inline image ![icon](images/example.png) sits in the text flow, and a
[link](https://example.com/) after it must still hit-test correctly. A broken
inline image ![missing alt](images/nope.png) falls back to italic alt text.

## Inline HTML (whitelist)

A small set of formatting tags is honoured: <b>bold</b>, <i>italic</i>,
<u>underline</u>, <s>struck</s>, <mark>highlight</mark>, <code>code</code>,
<kbd>Enter</kbd>, water is H<sub>2</sub>O, and x<sup>2</sup>. They nest:
<b>bold with <i>italic</i></b>. A hard break<br />comes from `<br>`.

Anything else stays literal and safe: <span style="color:red">span</span>.

HTML images size explicitly - here at 50% of the content width:

<img src="images/example.png" width="50%" alt="half width">

## Filler

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium
doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore
veritatis et quasi architecto beatae vitae dicta sunt explicabo.
