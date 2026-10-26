-- RunTrack – esquema de base de datos (Supabase / PostgreSQL)
-- Ejecutar en el SQL Editor de Supabase o como migración.
--
-- Cambios respecto al borrador inicial (hardening OWASP):
--  * A01 Broken Access Control: el usuario ya NO puede cambiar su propio `rol`
--    (antes, "FOR ALL" permitía auto-promoverse a entrenador).
--  * A01: las políticas llevan WITH CHECK, para que no se pueda insertar/mover
--    filas hacia otro usuario.
--  * A04 Insecure Design: el rol se fija a 'atleta' en el registro; el rol
--    'entrenador' solo lo concede un administrador (service role / SQL Editor).
--  * A03 Injection / integridad: restricciones CHECK sobre tipo y longitudes.

-- 1. Tipo de rol
CREATE TYPE user_role AS ENUM ('atleta', 'entrenador');

-- 2. Perfiles vinculados a auth.users
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  nombre TEXT NOT NULL CHECK (char_length(nombre) BETWEEN 1 AND 100),
  correo TEXT NOT NULL,
  rol user_role NOT NULL DEFAULT 'atleta',
  creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3. Entrenamientos
CREATE TABLE entrenamientos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  usuario_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  fecha DATE NOT NULL DEFAULT CURRENT_DATE,
  tipo TEXT NOT NULL CHECK (tipo IN
    ('Carrera continua', 'Intervalos', 'Recuperación', 'Tempo', 'Fondo', 'Otro')),
  distancia_km NUMERIC(5,2) NOT NULL CHECK (distancia_km > 0 AND distancia_km <= 500),
  duracion_segundos INTEGER NOT NULL CHECK (duracion_segundos > 0 AND duracion_segundos <= 604800),
  observaciones TEXT CHECK (char_length(observaciones) <= 1000),
  compartido_con_entrenador BOOLEAN NOT NULL DEFAULT FALSE,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX entrenamientos_usuario_fecha_idx
  ON entrenamientos (usuario_id, fecha DESC);

-- 4. Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE entrenamientos ENABLE ROW LEVEL SECURITY;

-- 5. Alta automática de perfil al registrarse.
--    El rol NUNCA se toma de datos enviados por el cliente (A01/A04).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, nombre, correo, rol)
  VALUES (
    NEW.id,
    left(coalesce(NEW.raw_user_meta_data ->> 'nombre', 'Corredor'), 100),
    NEW.email,
    'atleta'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. Función auxiliar: ¿el usuario actual es entrenador?
--    SECURITY DEFINER evita recursión de RLS al consultar `profiles`.
CREATE OR REPLACE FUNCTION public.es_entrenador()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid()) AND rol = 'entrenador'
  );
$$;

-- 7. Políticas: profiles
CREATE POLICY "Leer el propio perfil"
  ON profiles FOR SELECT
  USING ((SELECT auth.uid()) = id);

-- Solo se permite actualizar el perfil propio; el rol se protege más abajo.
CREATE POLICY "Actualizar el propio perfil"
  ON profiles FOR UPDATE
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- Impide cambiar `rol` desde la API: se revocan privilegios de columna
-- y solo se concede UPDATE sobre columnas no sensibles.
REVOKE UPDATE ON profiles FROM authenticated, anon;
GRANT UPDATE (nombre) ON profiles TO authenticated;

-- 8. Políticas: entrenamientos
CREATE POLICY "Atletas leen sus entrenamientos"
  ON entrenamientos FOR SELECT
  USING ((SELECT auth.uid()) = usuario_id);

CREATE POLICY "Atletas crean sus entrenamientos"
  ON entrenamientos FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = usuario_id);

CREATE POLICY "Atletas editan sus entrenamientos"
  ON entrenamientos FOR UPDATE
  USING ((SELECT auth.uid()) = usuario_id)
  WITH CHECK ((SELECT auth.uid()) = usuario_id);

CREATE POLICY "Atletas borran sus entrenamientos"
  ON entrenamientos FOR DELETE
  USING ((SELECT auth.uid()) = usuario_id);

-- Entrenadores: solo lectura de lo que el atleta compartió explícitamente.
CREATE POLICY "Entrenadores ven entrenamientos compartidos"
  ON entrenamientos FOR SELECT
  USING (compartido_con_entrenador = TRUE AND public.es_entrenador());
