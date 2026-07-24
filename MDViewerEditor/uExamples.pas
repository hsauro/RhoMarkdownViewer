unit uExamples;

interface

function GetExample1 : string;
function GetExample2 : string;
function GetExample3 : string;
function GetExample4 : string;
function GetExample5 : string;

implementation

function GetExample1 : string;
begin
  result := '''
    # Heading 1
    ## Heading 2
    ### Heading 3
    #### Heading 4
    ##### Heading 5
    ###### Heading 6

    This is a standard paragraph containing **bold text** (asterisks), __bold text__ (underscores), *italic text* (asterisks), and _italic text_ (underscores).

    You can also test ***bold and italic text*** or ~~strikethrough text~~.

    Here is an inline `code block` embedded inside a sentence.

    To test line breaks:
    This line ends with two spaces to force a soft break.
    This line is immediately below it.

    This line is separated by a blank line, creating a new paragraph block.

    ### Unordered List
    * Item 1
    * Item 2
      * Sub-item 2a (2 spaces indented)
      * Sub-item 2b
        * Deep sub-item 2b-i (4 spaces indented)

    ### Ordered List
    1. First step
    2. Second step
    3. Third step
       1. Sub-step A
       2. Sub-step B

    ### GFM Task List
    - [x] Completed task item
    - [ ] Incomplete task item
    - [x] ~~Completed and crossed out task~~

    > This is a standard single-level blockquote. It should look indented with a vertical accent bar on the left margin.
    >
    > > This is a nested second-level blockquote.
    > > It continues onto a second line here.
    >
    > Back to the first level of the blockquote.

    ---
    Above is a standard horizontal rule (`---`).
    ***
    Above is an alternative horizontal rule (`***`).
    ''';
  end;

  function GetExample2 : string;
  begin
    result := '''

  # My Document Title

  This is a simple paragraph. Markdown converts plain text into clean HTML.

  ## Section Heading

  You can easily emphasize text in a sentence. For example, this word is **bold** and this word is in *italics*.

  ### List of Items
  * This is the first item.
  * This is the second item.
  * This is the third item.

  ### Useful Links
  You can find the official specification on the [CommonMark Website](https://commonmark.org).

  ### Code Example
  To show inline code, wrap it in backticks like `project.config`.




  ### Hyperlinks
  * Standard link: [Visit W3Schools Markdown Tool](https://www.w3schools.com/tools/tool_markdown.php)
  * Link with tooltip hover: [GitHub Repository](https://github.com/mxstbr/markdown-test-file "Markdown Test File")
  * Autolink (if engine supports linkify): <https://markdown-it.github.io/>

  ### Images
  * Standard Image:
  ![Placeholder Image](https://picsum.photos)

  * Image with hovering title text:
  ![Placeholder Image](https://picsum.photos "Optional Title Text")

  * Broken Image (tests alt-text fallback handling):
  ![This text should display if the image breaks](https://thisisa.broken)



  | Feature | Description | Status |
  | :--- | :---: | ---: |
  | Left Aligned | Center Aligned | Right Aligned |
  | **Bold Feature** | `Inline Code` | $10.00 |
  | Long descriptive text cell goes here | Text | $100.00 |
  | Short | None | $0.00 |


  ```javascript
  // Test JavaScript syntax highlighting
  const greet = (name) => {
    const message = `Hello, ${name}!`;
    console.log(message);
    return true;
  };

  greet("Markdown Tester");
  ```

  ```python
  # Test Python syntax highlighting
  def calculate_total(price, tax_rate=0.08):
      """Returns total price with tax applied."""
      if price < 0:
          raise ValueError("Price cannot be negative")
      return price * (1 + tax_rate)
  ```



  ### HTML Pass-through
  Some viewers block HTML for safety, while others parse it. Test how this red text renders:
  <span style="color: red; font-weight: bold;">This text should be red and bold if HTML is supported.</span>

  ### Escaping Characters
  If parsing works correctly, you should see literal markdown symbols below instead of actual formatting:
  \* This is not a list item, it starts with an escaped asterisk.
  \# This is not a header, it starts with an escaped hashtag.
  \\ This is a literal backslash.

  ### GFM Alerts / Callouts
  If your viewer targets GitHub styling compatibility, these blockquotes will transform into visual alert blocks:

  > [!NOTE]
  > Useful information that users should know when viewing documents.

  > [!TIP]
  > Helpful advice to do things better or more efficiently.

  > [!IMPORTANT]
  > Crucial information necessary for users to succeed.

  > [!WARNING]
  > Critical content demanding immediate user attention to prevent errors.

  > [!CAUTION]
  > Negative consequences of an action that must be avoided.
  ''';
end;

function GetExample3 : string;
begin
  result := '''
  Colons can be used to align columns.

  | Tables        | Are           | Cool  |
  | ------------- |:-------------:| -----:|
  | col 3 is      | right-aligned | $1600 |
  | col 2 is      | centered      |   $12 |
  | zebra stripes | are neat      |    $1 |

  There must be at least 3 dashes separating each header cell.
  The outer pipes (|) are optional, and you don't need to make the
  raw Markdown line up prettily. You can also use inline Markdown.

  Markdown | Less | Pretty
  --- | --- | ---
  *Still* | `renders` | **nicely**
  1 | 2 | 3

  | First Header  | Second Header |
  | ------------- | ------------- |
  | Content Cell  | Content Cell  |
  | Content Cell  | Content Cell  |

  | Command | Description |
  | --- | --- |
  | git status | List all new or modified files |
  | git diff | Show file differences that haven't been staged |

  | Command | Description |
  | --- | --- |
  | `git status` | List all *new or modified* files |
  | `git diff` | Show file differences that **haven't been** staged |

  | Left-aligned | Center-aligned | Right-aligned |
  | :---         |     :---:      |          ---: |
  | git status   | git status     | git status    |
  | git diff     | git diff       | git diff      |

  | Name     | Character |
  | ---      | ---       |
  | Backtick | `         |
  | Pipe     | \|        |
  '''
end;


function GetExample4: string;
begin
  result := '''
  Emphasis, aka italics, with *asterisks* or _underscores_.

  Strong emphasis, aka bold, with **asterisks** or __underscores__.

  Combined emphasis with **asterisks and _underscores_**.

  Strikethrough uses two tildes. ~~Scratch this.~~

  **This is bold text**

  __This is bold text__

  *This is italic text*

  _This is italic text_

  ~~Strikethrough~~
  ''';
end;

// Showcases the container-block and inline-HTML features: quotes that nest and
// hold lists/code, list items with a second paragraph or a code block, indented
// code blocks, and the inline HTML whitelist (formatting tags + <img>).
function GetExample5: string;
begin
  result := '''
  # New in this build

  ## Block quotes as containers

  Quotes now nest and can hold other blocks.

  > A quote can contain a list:
  >
  > - first point
  > - second point
  >
  > ...and even a code block:
  >
  > ```pascal
  > WriteLn('inside a quote');
  > ```

  Nested quotes stack their bars:

  > level one
  >> level two
  >>> level three

  ## List items as containers

  - An item can have a second paragraph.

    This paragraph stays under the bullet instead of escaping the list.

  - An item can contain a code block:

    ```python
    def hello():
        print("indented under the item")
    ```

  - Back to a simple item.

  ## Indented code blocks

  Four spaces of indentation make a code block:

      procedure Indented;
      begin
        WriteLn('no fences needed');
      end;

  ## Inline HTML (whitelist)

  A small set of tags is honoured: <b>bold</b>, <i>italic</i>, <u>underline</u>, <s>struck</s>, <mark>highlight</mark>, <code>code()</code>, <kbd>Ctrl</kbd>, water is H<sub>2</sub>O, and x<sup>2</sup>. They nest: <b>bold with <i>italic</i></b>.

  Force a line break with the br tag<br />like this.

  Anything not whitelisted stays literal and safe: <span style="color:red">this is shown as text</span>.

  Images support explicit width via HTML (needs a local image beside the document):
  <img src="images/example.png" width="60%" alt="a 60%-width image">
  ''';
end;

end.
