import { test, expect } from "@playwright/test";

test("login and preview entry work without production credentials", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));

  await page.goto("/");
  await expect(page.getByRole("heading", { name: "تسجيل الدخول" })).toBeVisible();
  await expect(page.getByAltText("شعار سلسلة").first()).toBeVisible();

  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await expect(page.getByText("وضع المعاينة")).toBeVisible();
  await expect(page.getByRole("button", { name: "الملخص التنفيذي" })).toBeVisible();
  await expect(page.getByRole("button", { name: "عن البرنامج" })).toHaveCount(1);

  expect(pageErrors).toEqual([]);
});

test("main menus are grouped into basic data, movements and reports", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();

  await page.getByRole("button", { name: "المبيعات" }).click();
  await expect(page.getByRole("button", { name: "بيانات أساسية" })).toBeVisible();
  await expect(page.getByRole("button", { name: "حركات" })).toBeVisible();
  await expect(page.getByRole("button", { name: "تقارير" })).toBeVisible();

  await page.getByRole("button", { name: "عن البرنامج" }).click();
  await expect(page.getByRole("heading", { name: "منظومة إدارة الأعمال المتكاملة" })).toBeVisible();

  await page.getByRole("button", { name: "الملخص التنفيذي" }).click();
  await expect(page.getByText("صافي المبيعات")).toBeVisible();
});

test("sidebar collapse toggle stays available and exit dialog supports all choices", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();

  await page.getByRole("button", { name: "إخفاء القوائم" }).click();
  await expect(page.getByRole("button", { name: "إظهار القوائم" })).toBeVisible();
  await page.getByRole("button", { name: "إظهار القوائم" }).click();
  await expect(page.getByRole("button", { name: "إخفاء القوائم" })).toBeVisible();

  await page.getByRole("button", { name: "خروج من البرنامج" }).click();
  await expect(page.getByRole("dialog", { name: "تأكيد الخروج من البرنامج" })).toBeVisible();
  await page.getByRole("button", { name: "لا" }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);

  await page.getByRole("button", { name: "خروج من البرنامج" }).click();
  await page.getByRole("button", { name: "إلغاء الأمر" }).click();
  await expect(page.getByText("وضع المعاينة")).toBeVisible();
});

test("mobile preview does not create page-level horizontal overflow", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await page.getByRole("button", { name: /دخول المعاينة/ }).click();
  await expect(page.getByText("وضع المعاينة")).toBeVisible();

  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth
  }));
  expect(dimensions.content).toBeLessThanOrEqual(dimensions.viewport + 2);
});
