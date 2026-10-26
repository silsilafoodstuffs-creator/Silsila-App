# موصل سلسلة المحلي لأجهزة ZKTeco

هذا نموذج موصل يعمل على كمبيوتر Windows الموجود على شبكة جهاز البصمة. لا تشغّله على خادم عام، ولا تربط منفذه بالشبكة المحلية. يظل الاختبار الحقيقي غير مؤكد حتى يُشغّل على الكمبيوتر المتصل بالجهاز.

## الموديل الذي جرى التحضير له
- ZKTeco MB2000/ID
- IP: 192.168.2.200
- TCP: 4370
- Comm Key: 0

## المتطلبات
- Python 3.11 أو أحدث على Windows.
- الكمبيوتر قادر على الوصول للجهاز.
- لا يحتاج هذا الموصل إلى Supabase service-role key أو أي سر إداري لقاعدة البيانات.

## تشغيل أولي من PowerShell
افتح PowerShell داخل هذا المجلد، ثم نفّذ:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:SILSILA_ZK_TOKEN = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$env:SILSILA_ALLOWED_ORIGINS = "https://silsilafoodstuffs-creator.github.io"
.\.venv\Scripts\python.exe -m uvicorn app:app --host 127.0.0.1 --port 8765
```

احتفظ بقيمة SILSILA_ZK_TOKEN في نفس جلسة PowerShell عند الحاجة؛ لا تنشرها ولا ترسلها في محادثة. الخدمة مربوطة بـ 127.0.0.1 عمدًا ولا ينبغي تغييرها إلى 0.0.0.0.

## نقاط API
كل النقاط تتطلب رأس Authorization: Bearer <SILSILA_ZK_TOKEN>.
- GET http://127.0.0.1:8765/health
- POST http://127.0.0.1:8765/device/test
- POST http://127.0.0.1:8765/attendance/pull

جسم الطلب لاختبار الجهاز أو قراءة الحركات:
```json
{"ip":"192.168.2.200","port":4370,"comm_key":0,"timeout":8}
```

## حدود النسخة الحالية
- هذه نسخة أولية للموصل، وليست تكاملًا مكتملًا داخل شاشة سلسلة.
- قراءة الحركات تُرجع بيانات للجلسة ولا تحفظها في قاعدة البيانات.
- لا تمسح سجلات الجهاز ولا تعدّل المستخدمين أو البصمات.
- قد تختلف استجابة البروتوكول حسب إصدار الجهاز والبرنامج الثابت؛ يجب اختبار الاتصال ومقارنة الرقم التسلسلي المتوقع BRC7221760604 قبل اعتماد الربط.
- لا تعتبر حالة الجهاز «متصل» إلا بعد نجاح اختبار البروتوكول والتحقق من الهوية.
- قبل دمج المتصفح، يجب إدخال عنوان الموصل المحلي ورمز وصوله في إعدادات محلية آمنة. لا تضع الرمز داخل مستودع Git أو إعدادات الويب الثابتة.
