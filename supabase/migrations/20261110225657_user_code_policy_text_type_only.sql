UPDATE public.erp_program_policies
SET policy_value=jsonb_set(
  policy_value::jsonb,
  '{inheritance}',
  to_jsonb('يرث الأرقام من كود نوع المستخدم بدون البادئة Typ، ثم يضاف تسلسل مستقل من 5 أرقام؛ ولا يرث كود الموظف'::text),
  true
)::text,
updated_at=now()
WHERE policy_key='code_policy.user'
  AND left(policy_value,1)='{';
