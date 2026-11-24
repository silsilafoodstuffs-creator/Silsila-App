import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import App from "./App";

describe("Silsila category performance POC", () => {
  it("renders the isolated category experience and mock dataset", () => {
    const html = renderToStaticMarkup(<App />);
    expect(html).toContain("نموذج تجريبي معزول");
    expect(html).toContain("إدارة فئات الأصناف");
    expect(html).toContain("10,000");
    expect(html).toContain("لا يوجد اتصال بـ Supabase");
  });
});
