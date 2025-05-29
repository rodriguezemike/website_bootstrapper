#!/bin/bash
set -e

echo "Creating repo structure..."

mkdir -p backend/wasm-demo/rust-src/src
mkdir -p frontend/src/hooks
mkdir -p frontend/src/pages
mkdir -p .github/workflows

# Write backend files
cat > backend/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
import wasm3

app = FastAPI()

# Load WASM modules once on startup
with open("wasm-demo/rust_predict.wasm", "rb") as f:
    rust_wasm_bytes = f.read()
with open("wasm-demo/cpp_predict.wasm", "rb") as f:
    cpp_wasm_bytes = f.read()

env = wasm3.Environment()
runtime = env.new_runtime(1024)

rust_module = env.parse_module(rust_wasm_bytes)
runtime.load(rust_module)
rust_fn = runtime.find_function("rust_predict")

cpp_module = env.parse_module(cpp_wasm_bytes)
runtime.load(cpp_module)
cpp_fn = runtime.find_function("cpp_predict")


class PredictRequest(BaseModel):
    input_value: int


@app.post("/predict/rust")
def predict_rust(data: PredictRequest):
    res = rust_fn(data.input_value)
    return {"result": res}


@app.post("/predict/cpp")
def predict_cpp(data: PredictRequest):
    res = cpp_fn(data.input_value)
    return {"result": res}
EOF

cat > backend/wasm-demo/predict.cpp << 'EOF'
extern "C" {
    int cpp_predict(int x) {
        return x + 5;
    }
}
EOF

cat > backend/wasm-demo/rust-src/src/lib.rs << 'EOF'
#[no_mangle]
pub extern "C" fn rust_predict(x: i32) -> i32 {
    x * 3
}
EOF

cat > backend/wasm-demo/rust-src/Cargo.toml << 'EOF'
[package]
name = "rust_predict"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
EOF

cat > backend/wasm-demo/build.sh << 'EOF'
#!/bin/bash
set -e

echo "Building Rust WASM module..."
cd "$(dirname "$0")/rust-src"
cargo build --target wasm32-unknown-unknown --release
cp target/wasm32-unknown-unknown/release/rust_predict.wasm ../rust_predict.wasm

echo "Building C++ WASM module..."
cd ../
emcc predict.cpp -O3 -s WASM=1 -s SIDE_MODULE=1 -o cpp_predict.wasm

echo "Build complete."
ls -lh rust_predict.wasm cpp_predict.wasm
EOF

cat > backend/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential emscripten

COPY ./wasm-demo ./wasm-demo
COPY ./main.py ./main.py
COPY ./requirements.txt ./requirements.txt

RUN pip install -r requirements.txt

RUN chmod +x wasm-demo/build.sh && ./wasm-demo/build.sh

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > backend/requirements.txt << 'EOF'
fastapi
uvicorn
wasm3
pydantic
EOF

# Write frontend hooks and page
cat > frontend/src/hooks/useRustPredict.js << 'EOF'
import { useState } from "react";

export function useRustPredict() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);

  async function predict(value) {
    setLoading(true);
    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000"}/predict/rust`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ input_value: value }),
        }
      );
      const data = await res.json();
      setResult(data.result);
    } catch (e) {
      setResult(null);
      console.error(e);
    }
    setLoading(false);
  }

  return { predict, result, loading };
}
EOF

cat > frontend/src/hooks/useCppPredict.js << 'EOF'
import { useState } from "react";

export function useCppPredict() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);

  async function predict(value) {
    setLoading(true);
    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000"}/predict/cpp`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ input_value: value }),
        }
      );
      const data = await res.json();
      setResult(data.result);
    } catch (e) {
      setResult(null);
      console.error(e);
    }
    setLoading(false);
  }

  return { predict, result, loading };
}
EOF

cat > frontend/src/pages/wasm-demo.js << 'EOF'
import React, { useState } from "react";
import { useRustPredict } from "../hooks/useRustPredict";
import { useCppPredict } from "../hooks/useCppPredict";

export default function WasmDemo() {
  const [input, setInput] = useState(0);
  const { predict: rustPredict, result: rustResult, loading: rustLoading } = useRustPredict();
  const { predict: cppPredict, result: cppResult, loading: cppLoading } = useCppPredict();

  return (
    <div style={{ padding: 20 }}>
      <h1>WASM Rust & C++ Prediction Demo</h1>
      <input
        type="number"
        value={input}
        onChange={(e) => setInput(Number(e.target.value))}
      />
      <button onClick={() => rustPredict(input)} disabled={rustLoading}>
        Predict Rust
      </button>
      <button onClick={() => cppPredict(input)} disabled={cppLoading} style={{ marginLeft: 10 }}>
        Predict C++
      </button>

      <div style={{ marginTop: 20 }}>
        <p>Rust Prediction Result: {rustLoading ? "Loading..." : rustResult ?? "-"}</p>
        <p>C++ Prediction Result: {cppLoading ? "Loading..." : cppResult ?? "-"}</p>
      </div>
    </div>
  );
}
EOF

# Write README.md
cat > README.md << 'EOF'
# Mock AI Backend with Rust & C++ WASM and React/Next.js Frontend

## Overview

This project features:

- A FastAPI backend exposing prediction APIs
- WASM modules compiled from Rust and C++ for demo prediction logic
- React/Next.js frontend with hooks calling backend APIs
- Dockerized setup and build scripts
- CI/CD pipeline (to be added)

---

## Folder Structure

```

root/
├── backend/
│   ├── main.py               # FastAPI app calling WASM
│   ├── requirements.txt
│   ├── Dockerfile
│   └── wasm-demo/
│       ├── build.sh          # Build WASM modules
│       ├── predict.cpp       # C++ source
│       ├── cpp\_predict.wasm  # C++ WASM output (built)
│       ├── rust\_predict.wasm # Rust WASM output (built)
│       └── rust-src/
│           ├── Cargo.toml
│           └── src/lib.rs
│
├── frontend/
│   ├── src/
│   │   ├── hooks/
│   │   │   ├── useRustPredict.js
│   │   │   └── useCppPredict.js
│   │   └── pages/
│   │       └── wasm-demo.js
│   ├── package.json
│   └── next.config.js
│
├── docker-compose.yml        # Runs backend + frontend
├── init\_repo.sh              # Setup and git init script
└── README.md

````

---

## How to Build & Run

### Build WASM modules (backend)

```bash
cd backend/wasm-demo
./build.sh
````

### Run backend locally

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Run frontend locally

```bash
cd frontend
npm install
npm run dev
```

Open [http://localhost:3000/wasm-demo](http://localhost:3000/wasm-demo) to try.

Make sure backend URL is set correctly in `.env` or `NEXT_PUBLIC_BACKEND_URL`.

---

### Using Docker Compose

```bash
docker-compose up --build
```

---

## API Endpoints

* POST `/predict/rust` with JSON `{ "input_value": int }`
* POST `/predict/cpp` with JSON `{ "input_value": int }`

---

## Notes

* Rust WASM exports `rust_predict(int) -> int` (input \* 3)
* C++ WASM exports `cpp_predict(int) -> int` (input + 5)
* Backend loads WASM modules once and serves requests
* Frontend hooks handle API calls with loading and results states

---

## License

MIT

---

## Contact

Open issues or PRs for improvements.

---

*Happy hacking! 🚀*
EOF

git init
git add .
git commit -m "Initial commit: backend + frontend wasm integration"

# Set remote URL if you want here, e.g.:

# git remote add origin [git@github.com](mailto:git@github.com)\:yourusername/mock-ai-wasm.git

# git push -u origin main

echo "Repo initialized successfully!"

```

---

### How to use

1. Save this as `init_repo.sh`.
2. Run `chmod +x init_repo.sh`.
3. Run `./init_repo.sh`.
4. The repo structure with all files will be created.
5. Then build and run backend and frontend as per README instructions.

---

If you want me to generate the `docker-compose.yml`, frontend `package.json`, and `next.config.js` too, just ask!
```

penguin@LAPTOP-HT78DPJB:~/website_bootstrapper$ cat runme.sh
#!/bin/bash
set -e

echo "Creating repo structure..."

mkdir -p backend/wasm-demo/rust-src/src
mkdir -p frontend/src/hooks
mkdir -p frontend/src/pages
mkdir -p .github/workflows

# Write backend files
cat > backend/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
import wasm3

app = FastAPI()

# Load WASM modules once on startup
with open("wasm-demo/rust_predict.wasm", "rb") as f:
    rust_wasm_bytes = f.read()
with open("wasm-demo/cpp_predict.wasm", "rb") as f:
    cpp_wasm_bytes = f.read()

env = wasm3.Environment()
runtime = env.new_runtime(1024)

rust_module = env.parse_module(rust_wasm_bytes)
runtime.load(rust_module)
rust_fn = runtime.find_function("rust_predict")

cpp_module = env.parse_module(cpp_wasm_bytes)
runtime.load(cpp_module)
cpp_fn = runtime.find_function("cpp_predict")


class PredictRequest(BaseModel):
    input_value: int


@app.post("/predict/rust")
def predict_rust(data: PredictRequest):
    res = rust_fn(data.input_value)
    return {"result": res}


@app.post("/predict/cpp")
def predict_cpp(data: PredictRequest):
    res = cpp_fn(data.input_value)
    return {"result": res}
EOF

cat > backend/wasm-demo/predict.cpp << 'EOF'
extern "C" {
    int cpp_predict(int x) {
        return x + 5;
    }
}
EOF

cat > backend/wasm-demo/rust-src/src/lib.rs << 'EOF'
#[no_mangle]
pub extern "C" fn rust_predict(x: i32) -> i32 {
    x * 3
}
EOF

cat > backend/wasm-demo/rust-src/Cargo.toml << 'EOF'
[package]
name = "rust_predict"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
EOF

cat > backend/wasm-demo/build.sh << 'EOF'
#!/bin/bash
set -e

echo "Building Rust WASM module..."
cd "$(dirname "$0")/rust-src"
cargo build --target wasm32-unknown-unknown --release
cp target/wasm32-unknown-unknown/release/rust_predict.wasm ../rust_predict.wasm

echo "Building C++ WASM module..."
cd ../
emcc predict.cpp -O3 -s WASM=1 -s SIDE_MODULE=1 -o cpp_predict.wasm

echo "Build complete."
ls -lh rust_predict.wasm cpp_predict.wasm
EOF

cat > backend/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential emscripten

COPY ./wasm-demo ./wasm-demo
COPY ./main.py ./main.py
COPY ./requirements.txt ./requirements.txt

RUN pip install -r requirements.txt

RUN chmod +x wasm-demo/build.sh && ./wasm-demo/build.sh

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > backend/requirements.txt << 'EOF'
fastapi
uvicorn
wasm3
pydantic
EOF

# Write frontend hooks and page
cat > frontend/src/hooks/useRustPredict.js << 'EOF'
import { useState } from "react";

export function useRustPredict() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);

  async function predict(value) {
    setLoading(true);
    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000"}/predict/rust`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ input_value: value }),
        }
      );
      const data = await res.json();
      setResult(data.result);
    } catch (e) {
      setResult(null);
      console.error(e);
    }
    setLoading(false);
  }

  return { predict, result, loading };
}
EOF

cat > frontend/src/hooks/useCppPredict.js << 'EOF'
import { useState } from "react";

export function useCppPredict() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);

  async function predict(value) {
    setLoading(true);
    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000"}/predict/cpp`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ input_value: value }),
        }
      );
      const data = await res.json();
      setResult(data.result);
    } catch (e) {
      setResult(null);
      console.error(e);
    }
    setLoading(false);
  }

  return { predict, result, loading };
}
EOF

cat > frontend/src/pages/wasm-demo.js << 'EOF'
import React, { useState } from "react";
import { useRustPredict } from "../hooks/useRustPredict";
import { useCppPredict } from "../hooks/useCppPredict";

export default function WasmDemo() {
  const [input, setInput] = useState(0);
  const { predict: rustPredict, result: rustResult, loading: rustLoading } = useRustPredict();
  const { predict: cppPredict, result: cppResult, loading: cppLoading } = useCppPredict();

  return (
    <div style={{ padding: 20 }}>
      <h1>WASM Rust & C++ Prediction Demo</h1>
      <input
        type="number"
        value={input}
        onChange={(e) => setInput(Number(e.target.value))}
      />
      <button onClick={() => rustPredict(input)} disabled={rustLoading}>
        Predict Rust
      </button>
      <button onClick={() => cppPredict(input)} disabled={cppLoading} style={{ marginLeft: 10 }}>
        Predict C++
      </button>

      <div style={{ marginTop: 20 }}>
        <p>Rust Prediction Result: {rustLoading ? "Loading..." : rustResult ?? "-"}</p>
        <p>C++ Prediction Result: {cppLoading ? "Loading..." : cppResult ?? "-"}</p>
      </div>
    </div>
  );
}
EOF

# Write README.md
cat > README.md << 'EOF'
# Mock AI Backend with Rust & C++ WASM and React/Next.js Frontend

## Overview

This project features:

- A FastAPI backend exposing prediction APIs
- WASM modules compiled from Rust and C++ for demo prediction logic
- React/Next.js frontend with hooks calling backend APIs
- Dockerized setup and build scripts
- CI/CD pipeline (to be added)

---

## Folder Structure

```

root/
├── backend/
│   ├── main.py               # FastAPI app calling WASM
│   ├── requirements.txt
│   ├── Dockerfile
│   └── wasm-demo/
│       ├── build.sh          # Build WASM modules
│       ├── predict.cpp       # C++ source
│       ├── cpp\_predict.wasm  # C++ WASM output (built)
│       ├── rust\_predict.wasm # Rust WASM output (built)
│       └── rust-src/
│           ├── Cargo.toml
│           └── src/lib.rs
│
├── frontend/
│   ├── src/
│   │   ├── hooks/
│   │   │   ├── useRustPredict.js
│   │   │   └── useCppPredict.js
│   │   └── pages/
│   │       └── wasm-demo.js
│   ├── package.json
│   └── next.config.js
│
├── docker-compose.yml        # Runs backend + frontend
├── init\_repo.sh              # Setup and git init script
└── README.md

````

---

## How to Build & Run

### Build WASM modules (backend)

```bash
cd backend/wasm-demo
./build.sh
````

### Run backend locally

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Run frontend locally

```bash
cd frontend
npm install
npm run dev
```

Open [http://localhost:3000/wasm-demo](http://localhost:3000/wasm-demo) to try.

Make sure backend URL is set correctly in `.env` or `NEXT_PUBLIC_BACKEND_URL`.

---

### Using Docker Compose

```bash
docker-compose up --build
```

---

## API Endpoints

* POST `/predict/rust` with JSON `{ "input_value": int }`
* POST `/predict/cpp` with JSON `{ "input_value": int }`

---

## Notes

* Rust WASM exports `rust_predict(int) -> int` (input \* 3)
* C++ WASM exports `cpp_predict(int) -> int` (input + 5)
* Backend loads WASM modules once and serves requests
* Frontend hooks handle API calls with loading and results states

---

## License

MIT

---

## Contact

Open issues or PRs for improvements.

---

*Happy hacking! 🚀*
EOF

git init
git add .
git commit -m "Initial commit: backend + frontend wasm integration"

# Set remote URL if you want here, e.g.:

# git remote add origin [git@github.com](mailto:git@github.com)\:yourusername/mock-ai-wasm.git

# git push -u origin main

echo "Repo initialized successfully!"
