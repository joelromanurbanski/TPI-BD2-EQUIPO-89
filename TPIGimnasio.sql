-- ======================================================
--  TPIGimnasio
-- ======================================================

GO
CREATE DATABASE TPIGimnasio;
GO
USE TPIGimnasio;
GO

-- ======================================================
--  TABLAS
-- ======================================================

--------------------------------------------------
-- 1) TABLA PERSONA
--------------------------------------------------
CREATE TABLE Persona (
    IdPersona      INT IDENTITY(1,1) PRIMARY KEY,
    DNI            CHAR(8)       NOT NULL UNIQUE,     
    Apellido       NVARCHAR(100) NOT NULL,
    Nombre         NVARCHAR(100) NOT NULL,
    Direccion      NVARCHAR(200) NULL,
    FechaNacimiento DATE         NOT NULL,
    Email          NVARCHAR(150) NULL,
    EstadoCivil    NVARCHAR(50)  NULL
);
GO

--------------------------------------------------
-- 2) TABLA SOCIOS
--------------------------------------------------
CREATE TABLE Socios (
    IDSocio      INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona    INT          NOT NULL,
    Estado       BIT          NOT NULL DEFAULT 1,
    FechaAlta    DATETIME     NOT NULL DEFAULT GETDATE(),
    Observaciones NVARCHAR(300) NULL,
    CONSTRAINT FK_Socios_Persona
        FOREIGN KEY (IdPersona) REFERENCES Persona(IdPersona)
);
GO

--------------------------------------------------
-- 3) TABLA PASE (TIPOS DE PASE)
--------------------------------------------------
CREATE TABLE Pase (
    IDTipo INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL UNIQUE,
    Precio DECIMAL(10,2) NOT NULL DEFAULT 0
);
GO

--------------------------------------------------
-- 4) TABLA PASEPORSOCIO
--------------------------------------------------
CREATE TABLE PasePorSocio (
    IDPase        INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio       INT     NOT NULL,
    IDTipo        INT     NOT NULL,
    FechaInicio   DATE    NOT NULL,
    FechaFin      DATE    NOT NULL,
    VecesMax      INT     NULL,
    VecesUsadas   INT     NOT NULL DEFAULT 0,
    Estado        BIT     NOT NULL DEFAULT 1,
    FechaCreacion DATE  NULL,
    CONSTRAINT FK_Pases_Socio
        FOREIGN KEY (IDSocio) REFERENCES Socios(IDSocio),
    CONSTRAINT FK_Pases_Tipo
        FOREIGN KEY (IDTipo) REFERENCES Pase(IDTipo),
    CONSTRAINT CK_PPS_UsosNoSuperaMax
        CHECK (VecesMax IS NULL OR VecesUsadas <= VecesMax)
);
GO

--------------------------------------------------
-- 5) TABLA ASISTENCIAS
--------------------------------------------------
CREATE TABLE Asistencias (
    IDAsistencia INT IDENTITY(1,1) PRIMARY KEY,
    FechaHoraIng DATETIME NOT NULL DEFAULT GETDATE(),
    IdPase       INT      NOT NULL,
    CONSTRAINT FK_Asistencias_Pase
        FOREIGN KEY (IdPase) REFERENCES PasePorSocio(IDPase)
);
GO

--------------------------------------------------
-- 6) TABLA CLASEMAESTRA (tipo de clase)
--------------------------------------------------
CREATE TABLE ClaseMaestra (
    IdClaseMaestra INT IDENTITY(1,1) PRIMARY KEY,
    Nombre         NVARCHAR(100) NOT NULL UNIQUE,
    Descripcion    NVARCHAR(200) NULL,
    Activa         BIT           NOT NULL DEFAULT 1
);
GO

--------------------------------------------------
-- 7) TABLA PROFESORES
--------------------------------------------------
CREATE TABLE Profesores (
    IdProfesor  INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona   INT          NOT NULL,
    Especialidad NVARCHAR(100) NULL,
    Estado      BIT          NOT NULL DEFAULT 1,
    FechaAlta   DATETIME     NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Profesores_Persona
        FOREIGN KEY (IdPersona) REFERENCES Persona(IdPersona)
);
GO

--------------------------------------------------
-- 8) TABLA CLASEINSTANCIA (clase en un día/hora)
--------------------------------------------------
CREATE TABLE ClaseInstancia (
    IdClase        INT IDENTITY(1,1) PRIMARY KEY,
    IdClaseMaestra INT      NOT NULL,
    Fecha          DATE     NOT NULL,
    HoraInicio     TIME(7)  NOT NULL,
    HoraFin        TIME(7)  NOT NULL,
    Cupo          INT       NOT NULL,
    IdProfesor    INT       NULL,
    Activa        BIT       NOT NULL DEFAULT 1,
    CONSTRAINT FK_CI_Maestra
        FOREIGN KEY (IdClaseMaestra) REFERENCES ClaseMaestra(IdClaseMaestra),
    CONSTRAINT FK_CI_Profesor
        FOREIGN KEY (IdProfesor) REFERENCES Profesores(IdProfesor),
    CONSTRAINT CK_ClaseInstancia_Cupo
        CHECK (Cupo > 0)
);
GO

--------------------------------------------------
-- 9) TABLA HISTORIALMEDICO
--------------------------------------------------
CREATE TABLE HistorialMedico (
    IdHistorial   INT IDENTITY(1,1) PRIMARY KEY,
    IdSocio       INT          NOT NULL,
    FechaControl  DATE         NOT NULL DEFAULT GETDATE(),
    TipoControl   NVARCHAR(100) NOT NULL,
    Resultado     NVARCHAR(200) NULL,
    Observaciones NVARCHAR(200) NULL,
    CONSTRAINT FK_HistorialMedico_Socio
        FOREIGN KEY (IdSocio) REFERENCES Socios(IDSocio)
);
GO

--------------------------------------------------
-- 10) TABLA INSCRIPCIONES A CLASES
--------------------------------------------------
CREATE TABLE Inscripciones (
    IDInscripcion    INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio          INT          NOT NULL,
    IdClaseInstancia INT          NOT NULL,
    FechaAlta        DATETIME     NOT NULL DEFAULT GETDATE(),
    Estado           NVARCHAR(20) NOT NULL DEFAULT 'Activa',
    CONSTRAINT FK_Ins_Socio
        FOREIGN KEY (IDSocio) REFERENCES Socios(IDSocio),
    CONSTRAINT FK_Ins_ClaseInstancia
        FOREIGN KEY (IdClaseInstancia) REFERENCES ClaseInstancia(IdClase),
    CONSTRAINT UQ_Inscripciones_SocioClase
        UNIQUE (IDSocio, IdClaseInstancia),
    CONSTRAINT CK_Inscripciones_Estado
        CHECK (Estado IN ('Cambiada','Cancelada','Activa'))
);
GO


/* ============================
   VISTAS
============================ */

-- Pases próximos a vencer (dentro de 7 días)
CREATE VIEW vw_PasesProximosVencer AS
SELECT 
  P.IdPase,
  S.IdSocio,
  (Pe.Apellido + ', ' + Pe.Nombre) AS Socio,
  T.Nombre AS TipoPase,
  P.FechaFin,
  DATEDIFF(DAY, CAST(GETDATE() AS DATE), P.FechaFin) AS DiasRestantes
FROM dbo.PasePorSocio AS P
INNER JOIN dbo.Socios   AS S  ON S.IdSocio = P.IdSocio
INNER JOIN dbo.Persona  AS Pe ON Pe.IdPersona = S.IdPersona
INNER JOIN dbo.Pase     AS T  ON T.IdTipo   = P.IdTipo
WHERE P.Estado = 1
  AND P.FechaFin >= CAST(GETDATE() AS DATE)
  AND P.FechaFin <= DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
GO


-- Pases vigentes (activos hoy)
CREATE VIEW vw_PasesVigentes AS
SELECT 
  P.IdPase,
  P.IdSocio,
  (Pe.Apellido + ' ' + Pe.Nombre) AS NombreCompleto,
  T.Nombre AS TipoPase,
  P.FechaInicio,
  P.FechaFin,
  P.VecesMax,
  P.VecesUsadas,
  CASE 
      WHEN P.VecesMax IS NULL THEN NULL
      ELSE (P.VecesMax - P.VecesUsadas)
  END AS UsosRestantes
FROM dbo.PasePorSocio AS P
INNER JOIN dbo.Socios   AS S  ON S.IdSocio = P.IdSocio
INNER JOIN dbo.Persona  AS Pe ON Pe.IdPersona = S.IdPersona
INNER JOIN dbo.Pase     AS T  ON T.IdTipo   = P.IdTipo
WHERE P.Estado = 1
  AND CAST(GETDATE() AS DATE) BETWEEN P.FechaInicio AND P.FechaFin;
GO


-- Clases sin cupos disponibles
CREATE VIEW vw_ClasesSinCupos
AS
SELECT 
    ci.IdClase,
    cm.Nombre       AS NombreClase,
    ci.Fecha,
    ci.HoraInicio,
    ci.HoraFin,
    ci.Cupo,
    COUNT(i.IDInscripcion) AS CantInscriptos
FROM ClaseInstancia ci
INNER JOIN ClaseMaestra cm
    ON cm.IdClaseMaestra = ci.IdClaseMaestra
LEFT JOIN Inscripciones i
    ON i.IdClaseInstancia = ci.IdClase
   AND i.Estado = 'Activa'
WHERE ci.Activa = 1
GROUP BY 
    ci.IdClase,
    cm.Nombre,
    ci.Fecha,
    ci.HoraInicio,
    ci.HoraFin,
    ci.Cupo
HAVING COUNT(i.IDInscripcion) >= ci.Cupo;
GO

--Socio con edad

CREATE FUNCTION dbo.fn_CalcularEdad (@FechaNacimiento DATE)
RETURNS INT
AS
BEGIN
    DECLARE @Edad INT;

    -- Si la fecha es NULL, devolver NULL
    IF @FechaNacimiento IS NULL
        RETURN NULL;

    -- Diferencia básica en años
    SET @Edad = DATEDIFF(YEAR, @FechaNacimiento, GETDATE());

    -- Ajuste si todavía no cumplió años este año
    IF DATEADD(YEAR, @Edad, @FechaNacimiento) > CAST(GETDATE() AS DATE)
        SET @Edad = @Edad - 1;

    RETURN @Edad;
END;
GO


CREATE VIEW vw_SociosConEdad
AS
SELECT
    s.IdSocio,
    p.DNI,
    p.Apellido,
    p.Nombre,
    p.Email,
    dbo.fn_CalcularEdad(p.FechaNacimiento) AS Edad
FROM Socios s
JOIN Persona p ON p.IdPersona = s.IdPersona
WHERE s.Estado = 1;
GO

SELECT * FROM vw_SociosConEdad;

--Usos restantes
CREATE FUNCTION dbo.fn_UsosRestantes
(
    @VecesMax INT,
    @VecesUsadas INT
)
RETURNS INT
AS
BEGIN
    IF @VecesMax IS NULL
        RETURN NULL;  -- Pase ilimitado

    RETURN @VecesMax - @VecesUsadas;
END;
GO


CREATE VIEW vw_PasesConUsosRestantes
AS
SELECT
    pps.IDPase,
    s.IDSocio,
    per.Apellido + ' ' + per.Nombre AS Socio,
    pa.Nombre AS TipoPase,
    pps.FechaInicio,
    pps.FechaFin,
    pps.VecesMax,
    pps.VecesUsadas,
    dbo.fn_UsosRestantes(pps.VecesMax, pps.VecesUsadas) AS UsosRestantes,
    pps.Estado
FROM PasePorSocio pps
INNER JOIN Socios s ON s.IDSocio = pps.IDSocio
INNER JOIN Persona per ON per.IdPersona = s.IdPersona
INNER JOIN Pase pa ON pa.IDTipo = pps.IDTipo;
GO


/* ============================
   PROCEDIMIENTOS ALMACENADOS
============================ */

CREATE PROCEDURE sp_RegistrarAsistencia 
    @IdSocio INT, 
    @FechaHora DATETIME = NULL
AS
BEGIN
    BEGIN TRY
        IF @FechaHora IS NULL SET @FechaHora = GETDATE();

        DECLARE @IdPase INT, @IdTipo INT, @VecesMax INT, @VecesUsadas INT;

        -- Pase vigente del socio (activo y dentro de fechas)
        SELECT TOP 1
            @IdPase = PPS.IdPase,
            @IdTipo = PPS.IdTipo,
            @VecesMax = PPS.VecesMax,
            @VecesUsadas = PPS.VecesUsadas
        FROM PasePorSocio PPS
        WHERE PPS.IdSocio = @IdSocio
          AND PPS.Estado = 1
          AND CAST(@FechaHora AS DATE) BETWEEN PPS.FechaInicio AND PPS.FechaFin
        ORDER BY PPS.FechaFin ASC;

        IF @IdPase IS NULL
        BEGIN
            PRINT 'No hay pase vigente para este socio.';
            RETURN;
        END

        -- Límite de usos
        IF @VecesMax IS NOT NULL AND @VecesUsadas >= @VecesMax
        BEGIN
            PRINT 'El pase ya no tiene usos disponibles';
            RETURN;
        END

        -- Pase “diario”: una asistencia por día (si tu codificación es IdTipo=1)
        IF @IdTipo = 1 AND EXISTS (
            SELECT 1
            FROM Asistencias
            WHERE IdPase = @IdPase
              AND CONVERT(date, FechaHoraIng) = CONVERT(date, @FechaHora)
        )
        BEGIN
            PRINT 'El pase ya fue usado hoy.';
            RETURN;
        END

        BEGIN TRANSACTION;

        -- Registrar asistencia (ahora por IdPase)
        INSERT INTO Asistencias (IdPase, FechaHoraIng)
        VALUES (@IdPase, @FechaHora);

        -- Sumar uso si el pase tiene límite
        IF @VecesMax IS NOT NULL
        UPDATE PasePorSocio
        SET VecesUsadas = VecesUsadas + 1
        WHERE IdPase = @IdPase;

        -- Desactivar si se quedó sin usos o venció
        UPDATE PasePorSocio
        SET Estado = 0
        WHERE IdPase = @IdPase
          AND (
               (VecesMax IS NOT NULL AND VecesUsadas >= VecesMax)
               OR (CAST(@FechaHora AS DATE) > FechaFin)
          );

        COMMIT TRANSACTION;

        PRINT 'Asistencia registrada correctamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error al registrar asistencia.';
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO


CREATE PROCEDURE sp_AsistenciasMensual 
    @Anio INT, 
    @Mes  INT
AS
BEGIN
    BEGIN TRY
        DECLARE @AnioActual INT = YEAR(GETDATE());
        IF @Anio <> @AnioActual
        BEGIN
            PRINT 'Año invalido. Solo se permite el año actual.';
            RETURN;
        END

        IF @Mes < 1 OR @Mes > 12
        BEGIN
            PRINT 'Mes invalido.';
            RETURN;
        END

        DECLARE @Desde DATE = CAST(CAST(@Anio AS CHAR(4)) + RIGHT('0' + CAST(@Mes AS VARCHAR(2)), 2) + '01' AS DATE);
        DECLARE @Hasta DATE = DATEADD(MONTH, 1, @Desde);

        SELECT 
            S.IdSocio,
            (Pe.Apellido + ' ' + Pe.Nombre) AS Socio,
            COUNT(A.IdAsistencia)           AS CantidadAsistencias,
            MIN(A.FechaHoraIng)             AS PrimeraAsistencia,
            MAX(A.FechaHoraIng)             AS UltimaAsistencia
        FROM Socios S
        INNER JOIN Persona Pe       ON Pe.IdPersona = S.IdPersona
        LEFT  JOIN PasePorSocio PPS ON PPS.IdSocio = S.IdSocio
        LEFT  JOIN Asistencias A    ON A.IdPase = PPS.IdPase
                                   AND A.FechaHoraIng >= @Desde 
                                   AND A.FechaHoraIng <  @Hasta
        GROUP BY S.IdSocio, Pe.Apellido, Pe.Nombre
        ORDER BY CantidadAsistencias DESC;
    END TRY
    BEGIN CATCH
        PRINT 'Error al obtener el resumen mensual.';
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO

-- Listar Clases Disponibles
CREATE PROCEDURE sp_ListarClasesDisponibles
AS
BEGIN
    BEGIN TRY
        SELECT 
            ci.IdClase,
            cm.Nombre AS NombreClase,
            (pe.Apellido + ' ' + pe.Nombre) AS Profesor,
            ci.Fecha,
            ci.HoraInicio,
            ci.HoraFin,
            ci.Cupo,
            COUNT(i.IDInscripcion) AS Inscriptos,
            (ci.Cupo - COUNT(i.IDInscripcion)) AS LugaresDisponibles
        FROM ClaseInstancia ci
        INNER JOIN ClaseMaestra cm 
            ON cm.IdClaseMaestra = ci.IdClaseMaestra
        LEFT JOIN Profesores pr 
            ON pr.IdProfesor = ci.IdProfesor
        LEFT JOIN Persona pe 
            ON pe.IdPersona = pr.IdPersona
        LEFT JOIN Inscripciones i 
            ON i.IdClaseInstancia = ci.IdClase
           AND i.Estado = 'Activa'
        WHERE ci.Activa = 1
        GROUP BY 
            ci.IdClase, cm.Nombre,
            pe.Apellido, pe.Nombre,
            ci.Fecha, ci.HoraInicio, ci.HoraFin,
            ci.Cupo
        HAVING COUNT(i.IDInscripcion) < ci.Cupo
        ORDER BY ci.Fecha, ci.HoraInicio;

        PRINT 'Listado de clases con cupos disponibles generado correctamente.';
    END TRY
    BEGIN CATCH
        PRINT 'Error al listar las clases disponibles.';
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO

--Buscar socio por DNI

CREATE PROCEDURE sp_BuscarSocioPorDNI
(
    @DNI CHAR(8)
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.IDSocio,
        p.Apellido,
        p.Nombre,
        p.DNI,
        s.Estado,
        s.FechaAlta,
        s.Observaciones
    FROM Socios s
    INNER JOIN Persona p ON p.IdPersona = s.IdPersona
    WHERE p.DNI = @DNI;
END;
GO


/* ============================
   TRIGGERS
============================ */

--tr_Asistencias: Objetivo: Evita registrar dos asistencias el mismo día para el mismo socio.

CREATE TRIGGER tr_Asistencias_AI
ON Asistencias
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 
            i.IdPase,
            CONVERT(date, i.FechaHoraIng)
        FROM inserted i
        JOIN Asistencias a
            ON a.IdPase = i.IdPase
           AND CONVERT(date, a.FechaHoraIng) = CONVERT(date, i.FechaHoraIng)
           AND a.IdAsistencia <> i.IdAsistencia
    )
    BEGIN
        RAISERROR('El pase ya tiene una asistencia registrada para este día.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

CREATE TRIGGER tr_Inscripciones_Eliminar_ActualizarCupo
ON Inscripciones
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
	    
    UPDATE ci
    SET ci.Cupo = ci.Cupo + 1
    FROM ClaseInstancia ci
    INNER JOIN deleted d
        ON d.IdClaseInstancia = ci.IdClase;
END
GO

-- TRIGGER #3: Recalcula automáticamente el estado del pase
CREATE TRIGGER tr_PasePorSocio_RecalcularEstado
ON PasePorSocio
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
   
    UPDATE p
    SET Estado = CASE 
                    WHEN (p.VecesMax IS NOT NULL AND p.VecesUsadas >= p.VecesMax)
                         OR (CAST(GETDATE() AS DATE) > p.FechaFin)
                         THEN 0      
                    ELSE 1          
                 END
    FROM PasePorSocio p
    INNER JOIN inserted i
        ON i.IdPase = p.IdPase;
END
GO

UPDATE PasePorSocio
SET VecesUsadas = VecesUsadas + 1
WHERE IdPase = 6;

SELECT *
FROM PasePorSocio
WHERE IdPase = 6;


/* =========================================================
   0) LIMPIEZA DE DATOS DE PRUEBA 
   ========================================================= */
PRINT '--- Limpiando datos de prueba ---';

DELETE FROM Asistencias;
DELETE FROM Inscripciones;
DELETE FROM HistorialMedico;
DELETE FROM PasePorSocio;
DELETE FROM ClaseInstancia;
DELETE FROM ClaseMaestra;
DELETE FROM Profesores;
DELETE FROM Socios;
DELETE FROM Persona;
DELETE FROM Pase;
GO

-- Reiniciar IDENTITY (opcional, pero prolijo)
DBCC CHECKIDENT ('Persona', RESEED, 0);
DBCC CHECKIDENT ('Socios', RESEED, 0);
DBCC CHECKIDENT ('Profesores', RESEED, 0);
DBCC CHECKIDENT ('Pase', RESEED, 0);
DBCC CHECKIDENT ('PasePorSocio', RESEED, 0);
DBCC CHECKIDENT ('ClaseMaestra', RESEED, 0);
DBCC CHECKIDENT ('ClaseInstancia', RESEED, 0);
DBCC CHECKIDENT ('Inscripciones', RESEED, 0);
DBCC CHECKIDENT ('Asistencias', RESEED, 0);
DBCC CHECKIDENT ('HistorialMedico', RESEED, 0);
GO


/* =========================================================
   1) PERSONAS (10 PERSONAS COMPLETAS)
   ========================================================= */
PRINT '--- Insertando Personas ---';

INSERT INTO Persona
    (DNI,      Apellido,   Nombre,   Direccion,                  FechaNacimiento,  Email,                           EstadoCivil)
VALUES
    ('30000001','Gomez',   'Juan',   'Av. Siempre Viva 123',     '1990-05-15',     'juan.gomez@email.com',         'Soltero'),
    ('30000002','Perez',   'Maria',  'San Martin 450',           '1995-11-20',     'maria.perez@email.com',        'Soltera'),
    ('30000003','Lopez',   'Carlos', 'Belgrano 789',             '1988-03-10',     'carlos.lopez@email.com',       'Casado'),
    ('30000004','Garcia',  'Laura',  'Bv. Central 1000',         '1985-07-10',     'laura.garcia@email.com',       'Soltera'),
    ('30000005','Romero',  'Natalia','Italia 345',               '1992-02-05',     'natalia.romero@email.com',     'Casada'),
    ('30000006','Fernandez','Diego', 'Rivadavia 890',            '1998-09-25',     'diego.fernandez@email.com',    'Soltero'),
    ('30000007','Torres',  'Sofia',  'Mitre 230',                '2000-12-01',     'sofia.torres@email.com',       'Soltera'),
    ('30000008','Diaz',    'Martin', 'Colon 1200',               '1983-04-18',     'martin.diaz@email.com',        'Casado'),
    ('30000009','Sanchez', 'Paula',  'Sarmiento 760',            '1991-06-30',     'paula.sanchez@email.com',      'Soltera'),
    ('30000010','Ruiz',    'Andres', 'Av. Patria 55',            '1987-10-12',     'andres.ruiz@email.com',        'Divorciado');
GO



/* =========================================================
   2) SOCIOS (7 SOCIOS)
   ========================================================= */
PRINT '--- Insertando Socios ---';

INSERT INTO Socios (IdPersona, Estado, Observaciones)
VALUES
    (1, 1, 'Prefiere turno tarde'),          -- Juan
    (2, 1, 'Viene 3 veces por semana'),      -- Maria
    (3, 0, 'Inactivo por falta de pago'),    -- Carlos
    (5, 1, 'Asiste a funcional'),            -- Natalia
    (6, 1, 'Nuevo socio, alta reciente'),    -- Diego
    (7, 1, 'Practica spinning'),             -- Sofia
    (9, 1, 'Le interesan las clases de yoga'); -- Paula
GO
-- IdSocio: 1=Juan, 2=Maria, 3=Carlos, 4=Natalia, 5=Diego, 6=Sofia, 7=Paula


/* =========================================================
   3) PROFESORES (3 PROFESORES)
   ========================================================= */
PRINT '--- Insertando Profesores ---';

INSERT INTO Profesores (IdPersona, Especialidad)
VALUES
    (4, 'Yoga y Pilates'),      -- Laura
    (8, 'Musculacion'),         -- Martin
    (10,'Spinning y Funcional');-- Andres
GO
-- IdProfesor: 1=Laura, 2=Martin, 3=Andres


/* =========================================================
   4) TIPOS DE PASE (TABLA Pase)
   ========================================================= */
PRINT '--- Insertando Tipos de Pase ---';

INSERT INTO Pase (Nombre, Precio)
VALUES
    ('Pase Diario',        1500.00),   -- IDTipo 1
    ('Pase Mensual',      10000.00),   -- IDTipo 2
    ('Pase 8 Veces',       8000.00),   -- IDTipo 3
    ('Pase Libre Trimestral', 25000.00); -- IDTipo 4
GO


/* =========================================================
   5) PASES POR SOCIO (con fechas reales)
   ========================================================= */

INSERT INTO PasePorSocio
    (IDSocio, IDTipo, FechaInicio, FechaFin, VecesMax, VecesUsadas, Estado, FechaCreacion)
VALUES
    -- Socio 1 (Juan): Pase Mensual vigente
    (1, 2, '2025-10-10', '2025-12-10', NULL, 0, 1, '2025-10-10'),

    -- Socio 2 (Maria): Pase 8 Veces, próximo a vencer
    (2, 3, '2025-10-25', '2025-12-05', 8, 5, 1, '2025-10-25'),

    -- Socio 3 (Carlos): Pase vencido
    (3, 2, '2025-08-01', '2025-10-01', NULL, 0, 0, '2025-08-01'),

    -- Socio 4 (Natalia): Pase Trimestral vigente
    (4, 4, '2025-10-15', '2026-01-15', NULL, 3, 1, '2025-10-15'),

    -- Socio 5 (Diego): Pase 8 veces casi agotado
    (5, 3, '2025-11-01', '2025-12-01', 8, 7, 1, '2025-11-01'),

    -- Socio 6 (Sofia): Pase Diario vencido
    (6, 1, '2025-11-18', '2025-11-19', 1, 1, 0, '2025-11-18'),

    -- Socio 7 (Paula): Pase Mensual próximo a vencer
    (7, 2, '2025-10-20', '2025-11-22', NULL, 2, 1, '2025-10-20');
GO



/* =========================================================
   6) HISTORIAL MEDICO 
   ========================================================= */

INSERT INTO HistorialMedico
    (IdSocio, FechaControl, TipoControl, Resultado, Observaciones)
VALUES
    (1, '2025-09-20', 'Apto Fisico', 'Apto', 'Sin observaciones'),
    (2, '2025-10-10', 'Apto Fisico', 'Apto', 'Control de rutina'),
    (4, '2025-11-01', 'Apto Fisico', 'Apto', 'Recomendado cuidado de rodilla');
GO

/* =========================================================
   7) CLASES MAESTRA
   ========================================================= */
PRINT '--- Insertando ClaseMaestra ---';

INSERT INTO ClaseMaestra (Nombre, Descripcion, Activa)
VALUES
    ('Yoga',        'Clase de Yoga Hatha',          1), -- IdClaseMaestra 1
    ('Spinning',    'Ciclismo indoor',              1), -- 2
    ('Funcional',   'Entrenamiento funcional',      1), -- 3
    ('Musculacion', 'Entrenamiento de fuerza',      1); -- 4
GO


/* =========================================================
   8) CLASES INSTANCIA 
   ========================================================= */
PRINT '--- Insertando ClaseInstancia ---';

-- Usamos fechas reales cercanas, por ejemplo de noviembre y diciembre de 2025:
INSERT INTO ClaseInstancia
    (IdClaseMaestra, Fecha,       HoraInicio, HoraFin, Cupo, IdProfesor, Activa)
VALUES
    (1, '2025-11-20', '18:00', '19:00',  2, 1, 1),  -- Yoga Jueves 20/11 (Cupo 2 para poder llenarla)
    (2, '2025-11-21', '19:00', '20:00', 15, 3, 1),  -- Spinning Viernes
    (3, '2025-11-22', '17:00', '18:00', 10, 3, 1),  -- Funcional Sabado
    (4, '2025-11-23', '10:00', '11:00', 20, 2, 1);  -- Musculacion Domingo
GO
-- IdClase: 1,2,3,4


/* =========================================================
   9) INSCRIPCIONES (una clase llena para probar ClasesSinCupos)
   ========================================================= */
PRINT '--- Insertando Inscripciones ---';

-- Clase 1 (Yoga, Cupo 2) -> la llenamos
INSERT INTO Inscripciones (IDSocio, IdClaseInstancia, Estado)
VALUES
    (1, 1, 'Activa'),  -- Juan a Yoga
    (2, 1, 'Activa');  -- Maria a Yoga (Clase 1 queda sin cupo)

-- Clase 2 (Spinning) -> algunos inscriptos, pero no llena
INSERT INTO Inscripciones (IDSocio, IdClaseInstancia, Estado)
VALUES
    (4, 2, 'Activa'),  -- Natalia a Spinning
    (5, 2, 'Activa');  -- Diego a Spinning
GO


/* =========================================================
   10) ASISTENCIAS (con fechas reales)
   ========================================================= */

-- Maria (Pase ID 2)
INSERT INTO Asistencias (IdPase, FechaHoraIng)
VALUES
    (2, '2025-11-10 18:30'),
    (2, '2025-11-12 18:45'),
    (2, '2025-11-15 19:00');

-- Juan (Pase ID 1)
INSERT INTO Asistencias (IdPase, FechaHoraIng)
VALUES
    (1, '2025-11-18 17:59');

-- Diego (Pase ID 5)
INSERT INTO Asistencias (IdPase, FechaHoraIng)
VALUES
    (5, '2025-11-19 19:15');
GO


