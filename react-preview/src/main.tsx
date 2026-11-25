import React, { lazy, Suspense } from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

const AuthGate = lazy(() => import("./AuthGate"));

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <Suspense fallback={<div className="workspace-loading" role="status">جارٍ تشغيل سلسلة...</div>}>
      <AuthGate><App /></AuthGate>
    </Suspense>
  </React.StrictMode>
);
