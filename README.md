<div align="center"\>

[![](https://cdn.jsdelivr.net/npm/@intergrav/devins-badges@3.2.0/assets/cozy/social/youtube-singular_vector.svg)](https://youtube.com/@pedrli_) [![](https://cdn.jsdelivr.net/npm/@intergrav/devins-badges@3.2.0/assets/cozy/social/twitter-singular_vector.svg)](https://x.com/pedro_denovo)

</div>

# Godot Android WebView

A plugin to integrate native Android WebViews into your **Godot 4.2+** projects as a fully interactive `Control` node.

This plugin allows you to render web content (local or online) as part of your user interface, ideal for login screens, news feeds, leaderboards, or even creating your entire game's UI using web technologies.

The API is heavily inspired by the excellent [godot-wry](https://github.com/doceazedo/godot_wry/tree/main) plugin by **doceazedo**, bringing a familiar and powerful development experience to the Android platform.

## ✨ Features

  * **Native Performance:** Renders the `WebView` as an overlay, ensuring maximum performance without impacting your game's FPS.
  * **Integrated `Control` Node:** Add a `WebViewControl` to your scene and manipulate it like any other Godot UI node.
  * **Automatic Synchronization:** Position, size, and visibility are automatically synchronized with the `Control` node.
  * **Intelligent Mouse Filter:** Full support for the `Mouse Filter` property (`Stop`, `Pass`, `Ignore`) to control which touches pass through to the game and which are captured by the web content.
  * **Transparent Background:** Create floating interfaces and HUDs over your game with full transparency support.
  * **Bidirectional Communication (IPC):** Allows Godot and JavaScript to talk to each other by sending and receiving messages.
  * **Familiar API:** The GDScript API mirrors the features and convenience of `godot-wry`.

## 📦 Installation

1.  Go to the [**Releases**](https://github.com/pedrodenovo/Godot-AWV/releases) page and download the latest version of the plugin.
2.  Extract the zip file.
3.  Copy the `addons` folder to the root of your Godot project. The final structure should be `res://addons/godot_awv/`.
4.  Open your project, go to `Project > Project Settings... > Plugins` and enable the `Godot AWV` plugin.

## 🚀 How to Use

The simplest way to use the plugin is to add the `WebViewControl` node to your scene.

1.  In your scene, click "Add Child Node" and search for `WebViewControl`.
2.  Add the node to your scene tree.
3.  Select the `WebViewControl` node and, in the Inspector, you can configure initial properties like `url` or `html`.

**Simple example in a parent script:**

```gdscript
extends Node

@onready var web_view: WebViewControl = $WebViewControl

func _ready():
    # Connect the signal to know when the page has loaded
    web_view.page_loaded.connect(_on_page_loaded)
    
    # Load a URL when the game starts
    web_view.load_url("https://godotengine.org")

func _on_page_loaded(url: String):
    print("Page %s loaded successfully!" % url)
```

## 📚 API Reference

The `WebViewControl` attempts to mirror the `godot-wry` API.

### Properties

| Property               | Type   | Description                                                                                                   |
| ---------------------- | ------ | ------------------------------------------------------------------------------------------------------------- |
| `full_window_size`     | bool   | Makes the WebView always match the size of the game window.                                                   |
| `url`                  | String | Initial URL to be loaded. Overrides the `html` property.                                                      |
| `html`                 | String | HTML code to be loaded. Ignored if `url` is provided.                                                         |
| `transparent`          | bool   | Defines if the WebView's background should be transparent.                                                    |
| `autoplay`             | bool   | Allows media (audio/video) to play automatically without user interaction.                                    |
| `background_color`     | Color  | Background color of the WebView. Ignored if `transparent` is `true`.                                          |
| `devtools`             | bool   | Enables remote debugging of the WebView via `chrome://inspect` on a desktop browser.                            |
| `user_agent`           | String | Defines a custom User Agent for requests.                                                                     |
| `incognito`            | bool   | Attempts to simulate an incognito mode (no cache, cookies, or storage).                                       |
| `focused_when_created` | bool   | The WebView will attempt to gain focus upon creation.                                                         |
| `forward_input_events` | bool   | Equivalent to `Mouse Filter = Pass`. If `true`, touches on non-interactive areas pass through to the game. |

### Selected Methods

  * `load_url(url: String)`: Navigates to a URL.
  * `load_html(html: String)`: Loads HTML content.
  * `post_message(message: String)`: Sends a message to JavaScript.
  * `eval(js: String)`: Executes JavaScript code in the page's context.
  * `reload()`: Reloads the current page.
  * `focus()`: Requests focus for the WebView (e.g., to bring up the keyboard).
  * `focus_parent()`: Returns focus to the main game window.
  * `clear_all_Browse_data()`: Clears cache, cookies, and other Browse data.
  * `zoom(factor: float)`: Applies a zoom factor to the page (1.0 is default).
  * `print()`: Opens the Android print interface.

### Signals

  * `page_loaded(url: String)`: Emitted when a page finishes loading.
  * `ipc_message(message: String)`: Emitted when JavaScript sends a message to Godot via `godotPort.postMessage()`.
  * `eval_result(result: String)`: Emitted with the result of code execution via `eval()`.

## 💡 Advanced Example: Transparent HUD with IPC

You can use the WebView to create your game's interface.

**1. Create the `hud.html` file:**

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        html, body {
            background-color: transparent;
            font-family: sans-serif;
            color: white;
            pointer-events: none; /* Let touches pass through by default */
        }
        #interactive-area {
            position: absolute;
            bottom: 20px;
            right: 20px;
            pointer-events: auto; /* Re-enable touches for this area */
        }
        #my-button {
            background: #4CAF50; padding: 15px; border-radius: 5px;
        }
    </style>
</head>
<body>
    <div id="interactive-area">
        <button id="my-button" onclick="sendMessage()">Send to Godot</button>
    </div>
    <script>
        let godotPort = null;
        window.addEventListener('message', e => {
            if (e.data === 'init_port') godotPort = e.ports[0];
        });
        function sendMessage() {
            if (godotPort) godotPort.postMessage("HTML button clicked!");
        }
    </script>
</body>
</html>
```

**2. In your GDScript:**

```gdscript
extends Node

@onready var web_view: WebViewControl = $WebViewControl

func _ready():
    # Connect the signal to receive the message from the button
    web_view.ipc_message.connect(func(msg): print(msg))
    
    # Configure the HUD to be transparent and fill the entire screen
    web_view.transparent = true
    web_view.full_window_size = true
    # Allows touches to pass through empty areas
    web_view.forward_input_events = true
    
    # Load our HTML
    var file = FileAccess.open("res://hud.html", FileAccess.READ)
    if file:
        web_view.load_html(file.get_as_text())
```

## 🏗️ Building from Source

If you want to modify the plugin, you will need Android Studio or the Android SDK Command-line Tools.

1.  Clone the repository.
2.  Open a terminal in the project folder.
3.  Run the command `./gradlew assemble` (or `gradlew.bat assemble` on Windows).
4.  The compiled `.aar` files will be in the `plugin/build/outputs/aar/` folder.
