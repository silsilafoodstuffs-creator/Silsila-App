import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import App from "./App";

describe("Silsila connected category workspace", () => {
  it("renders a configuration prompt without exposing mock records when env is absent", () => {
    const html = renderToStaticMarkup(<App />);
    expect(html).toContain("إدارة اتصال قاعدة البيانات");
    expect(html).not.toContain("10,000");
  });
});
