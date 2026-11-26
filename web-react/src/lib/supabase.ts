import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim();
const supabasePublishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim();

export const supabaseConfigError =
  !supabaseUrl || !supabasePublishableKey
    ? "إعدادات الاتصال غير مكتملة. يلزم ضبط رابط مشروع Supabase ومفتاح Publishable في متغيرات بيئة النشر."
    : "";

export const supabase =
  supabaseUrl && supabasePublishableKey
    ? createClient(supabaseUrl, supabasePublishableKey, {
        auth: {
          autoRefreshToken: true,
          persistSession: true,
          detectSessionInUrl: true,
        },
        db: { schema: "public" },
      })
    : null;
