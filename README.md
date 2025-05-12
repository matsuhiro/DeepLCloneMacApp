# DeepLCloneMacApp

A lightweight macOS menu-bar translator inspired by DeepL, using an OpenAI-compatible API under the hood.  
Type or paste text in the main window, press **⌘+G** from any app to pop it up with your clipboard contents, and get an instant AI-powered translation.

---

## 🛠 Features

- **Menu-bar app** with a pop-up window  
- **⌘+G global hotkey** to invoke from any app (does not swallow standard shortcuts)  
- **Debounced input** (0.5 s idle) to avoid spamming requests  
- **Auto-detect input language** (or choose manually)  
- **Select target language** manually  
- **Clipboard paste on launch**: if there’s text in your clipboard when the app starts, it’s auto-pasted  
- **Settings screen** to configure:  
  - API key (SecureField)  
  - API base URL  
  - Available models (add, select, delete)  
- **Debug logging** (enabled in Debug builds) of requests and responses  

---

## 🚀 Getting Started

### Prerequisites

- **macOS 12+**  
- **Xcode 14+**  
- A valid **OpenAI-compatible API key** and endpoint

### Installation

```bash
# 1. Clone this repo
git clone https://github.com/yourname/DeepLCloneMacApp.git
cd DeepLCloneMacApp

# 2. Open in Xcode
open DeepLCloneMacApp.xcodeproj
