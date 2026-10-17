-- Notify suppliers when a customer places an order and customers when order status changes.
BEGIN;

CREATE OR REPLACE FUNCTION public.silsila_notify_order_events()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.supplier_id IS NOT NULL THEN
      INSERT INTO public.notifications (
        user_id, title, body, notification_type, type, order_id, data
      ) VALUES (
        NEW.supplier_id,
        'طلب جديد على سلسلة',
        'لديك طلب جديد رقم ' || NEW.id || ' يحتاج إلى المراجعة.',
        'order', 'order', NEW.id,
        jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
      );
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.notifications (
      user_id, title, body, notification_type, type, order_id, data
    ) VALUES (
      NEW.customer_id,
      'تحديث حالة الطلب',
      'تم تحديث حالة طلبك رقم ' || NEW.id || ' إلى: ' || NEW.status,
      'order', 'order', NEW.id,
      jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
    );

    IF NEW.supplier_id IS NOT NULL AND NEW.status = 'مُلغي'
       AND OLD.status <> 'مُلغي' THEN
      INSERT INTO public.notifications (
        user_id, title, body, notification_type, type, order_id, data
      ) VALUES (
        NEW.supplier_id,
        'تم إلغاء الطلب',
        'تم إلغاء الطلب رقم ' || NEW.id || '.',
        'order', 'order', NEW.id,
        jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS silsila_order_notifications ON public.orders;
CREATE TRIGGER silsila_order_notifications
AFTER INSERT OR UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.silsila_notify_order_events();

COMMIT;
