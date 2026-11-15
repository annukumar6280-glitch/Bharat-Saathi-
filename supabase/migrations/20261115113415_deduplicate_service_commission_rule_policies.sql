-- Avoid two permissive SELECT policies while preserving admin visibility.
DROP POLICY IF EXISTS "Admins manage service commission rules" ON public.service_commission_rules;
DROP POLICY IF EXISTS "Authenticated users read active service commission rules" ON public.service_commission_rules;

CREATE POLICY "Authenticated users read active or admin service commission rules"
ON public.service_commission_rules
FOR SELECT
TO authenticated
USING (is_active = true OR public.is_bharat_saathi_admin());

CREATE POLICY "Admins insert service commission rules"
ON public.service_commission_rules
FOR INSERT
TO authenticated
WITH CHECK (public.is_bharat_saathi_admin());

CREATE POLICY "Admins update service commission rules"
ON public.service_commission_rules
FOR UPDATE
TO authenticated
USING (public.is_bharat_saathi_admin())
WITH CHECK (public.is_bharat_saathi_admin());

CREATE POLICY "Admins delete service commission rules"
ON public.service_commission_rules
FOR DELETE
TO authenticated
USING (public.is_bharat_saathi_admin());
