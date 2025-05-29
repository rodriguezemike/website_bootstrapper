# 🧠 Bootstrapper for web based AI projects

A full-stack bootstrapper integrating **WASM modules written in Rust and C++** with a **FastAPI backend** and a **React/Next.js frontend**. Predictions are made via WebAssembly for performance and cross-language experimentation.

---

## 🗂️ Project Structure

```
root/
├── backend/
│   ├── main.py               # FastAPI app exposing prediction APIs
│   ├── Dockerfile            # Container setup
│   ├── requirements.txt      # Python dependencies
│   └── wasm-demo/
│       ├── build.sh          # Compiles WASM modules
│       ├── predict.cpp       # C++ source code
│       ├── cpp_predict.wasm  # Compiled C++ WASM
│       ├── rust_predict.wasm # Compiled Rust WASM
│       └── rust-src/
│           ├── Cargo.toml    # Rust config
│           └── src/lib.rs    # Rust source
│
├── frontend/
│   ├── src/
│   │   ├── hooks/
│   │   │   ├── useRustPredict.js
│   │   │   └── useCppPredict.js
│   │   └── pages/
│   │       └── wasm-demo.js  # UI to interact with prediction APIs
│   ├── package.json
│   └── next.config.js
│
├── .github/
│   └── workflows/            # Placeholder for CI/CD
│
├── docker-compose.yml        # (Optional) Compose setup
├── init_repo.sh              # Auto repo generator script
└── README.md
```

---

## 🚀 Quick Start

### 1. Build WASM Modules

```bash
cd backend/wasm-demo
./build.sh
```

This will:

* Compile Rust code into `rust_predict.wasm`
* Compile C++ code into `cpp_predict.wasm`

---

### 2. Run Backend (FastAPI)

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

---

### 3. Run Frontend (Next.js)

```bash
cd frontend
npm install
npm run dev
```

Visit: [http://localhost:3000/wasm-demo](http://localhost:3000/wasm-demo)

📌 **Note:** Ensure `NEXT_PUBLIC_BACKEND_URL` is set in a `.env` file or defaults to `http://localhost:8000`.

---

### 🔄 Run with Docker Compose (Optional)

```bash
docker-compose up --build
```

---

## 🧪 API Endpoints

* `POST /predict/rust` → `{ "input_value": int }` → `result = input * 3`
* `POST /predict/cpp` → `{ "input_value": int }` → `result = input + 5`

---

## 🧬 How It Works

### Rust Module (`lib.rs`)

```rust
#[no_mangle]
pub extern "C" fn rust_predict(x: i32) -> i32 {
    x * 3
}
```

### C++ Module (`predict.cpp`)

```cpp
extern "C" {
    int cpp_predict(int x) {
        return x + 5;
    }
}
```

### Backend

* Loads both `.wasm` files using `wasm3`
* Exposes FastAPI routes that call the appropriate WASM functions

### Frontend

* React hooks (`useRustPredict`, `useCppPredict`) manage state and API calls
* One-page demo to input a number and get both predictions

---

## 📄 License

[MIT License](LICENSE)

---

## 🙋‍♀️ Contributions

Open to pull requests and suggestions!

---

## 📬 Contact

File issues or reach out via GitHub Discussions (if enabled).

---

🛠️ Built with **FastAPI**, **Rust**, **C++**, **WebAssembly**, **Next.js**, and ❤️

---

Let me know if you'd like a `docker-compose.yml` or `.env.example` template added too!
