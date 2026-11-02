-- VISCERA : le bouton « Tout effacer » est exclusivement réservé
-- à l'administrateur APPROUVÉ. Pas de changement du droit « marquer lu ».
-- Ne change jamais la propriété (user_id) d'une notification.
CREATE OR REPLACE FUNCTION public.viscera_enforce_admin_notification_dismissal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.dismissed_at IS DISTINCT FROM OLD.dismissed_at THEN
    IF (SELECT auth.uid()) IS NULL
       OR NOT EXISTS (
         SELECT 1
         FROM public.doctor_profiles AS doctor
         WHERE doctor.user_id = (SELECT auth.uid())
           AND doctor.user_id = OLD.user_id
           AND doctor.is_admin IS TRUE
           AND doctor.approval_status = 'approved'
       )
    THEN
      RAISE EXCEPTION
        'Seul l’administrateur approuvé peut effacer les notifications.'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.viscera_enforce_admin_notification_dismissal()
  FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS viscera_admin_only_notification_dismissal
  ON public.viscera_notifications;
CREATE TRIGGER viscera_admin_only_notification_dismissal
BEFORE UPDATE ON public.viscera_notifications
FOR EACH ROW
EXECUTE FUNCTION public.viscera_enforce_admin_notification_dismissal();
