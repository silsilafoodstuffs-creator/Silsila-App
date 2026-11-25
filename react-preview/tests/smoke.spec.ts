import { test, expect } from "@playwright/test";

test("login and preview entry work without production credentials", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));

  await page.goto("/");
  await expect(page.getByRole("heading", { name: "تسجيل الدخول" })).toBeVisible();
  await expect(page.getByAltText("شعار سلسلة").first()).toBeVisible();

  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await expect(page.getByText("معاينة محلية فقط")).toBeVisible();
  await expect(page.getByRole("button", { name: "الملخص التنفيذي" })).toBeVisible();

  expect(pageErrors).toEqual([]);
});

test("mobile preview does not create page-level horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await expect(page.getByText("معاينة محلية فقط")).toBeVisible();

  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth
  }));
  expect(dimensions.content).toBeLessThanOrEqual(dimensions.viewport + 2);
});
