-- ======================================================
--  TPIGimnasio
-- ======================================================

GO
CREATE DATABASE TPIGimnasio;
GO
USE TPIGimnasio;
GO

-- ======================================================
-- 1) TABLAS
-- ======================================================

-- 1.1) PERSONA
CREATE TABLE Persona(
    IdPersona INT IDENTITY(1,1) PRIMARY KEY,
    DNI       CHAR(8)        NOT NULL UNIQUE,
    Apellido  NVARCHAR(100)  NOT NULL,
    Nombre    NVARCHAR(100)  NOT NULL
);
GO

-- 1.2) SOCIOS
CREATE TABLE Socios(
    IDSocio         INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona       INT             NOT NULL,
    Email           NVARCHAR(150)   NOT NULL,
    Estado          BIT             NOT NULL CONSTRAINT DF_Socios_Estado DEFAULT(1),
    FechaNacimiento DATE            NULL,
    FechaAlta       DATETIME        NOT NULL CONSTRAINT DF_Socios_FechaAlta DEFAULT(GETDATE()),
    CONSTRAINT UQ_Socios_Email UNIQUE(Email),
    CONSTRAINT FK_Socios_Persona FOREIGN KEY(IdPersona) REFERENCES dbo.Persona(IdPersona)
);
GO

-- 1.3) PROFESORES
CREATE TABLE Profesores(
    IdProfesor   INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona    INT             NOT NULL,
    Especialidad NVARCHAR(100)   NULL,
    Estado       BIT             NOT NULL CONSTRAINT DF_Profesores_Estado DEFAULT(1),
    FechaAlta    DATETIME        NOT NULL CONSTRAINT DF_Profesores_FechaAlta DEFAULT(GETDATE()),
    CONSTRAINT FK_Profesores_Persona FOREIGN KEY(IdPersona) REFERENCES dbo.Persona(IdPersona)
);
GO

-- 1.4) TIPOS DE PASE
CREATE TABLE TiposPase(
    IDTipo  INT IDENTITY(1,1) PRIMARY KEY,
    Nombre  NVARCHAR(100) NOT NULL UNIQUE,
    Precio  DECIMAL(10,2) NOT NULL CONSTRAINT DF_TiposPase_Precio DEFAULT(0)
);
GO

-- 1.5) PASES
CREATE TABLE Pases(
    IDPase      INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio     INT          NOT NULL,
    IDTipo      INT          NOT NULL,
    FechaInicio DATE         NOT NULL,
    FechaFin    DATE         NOT NULL,
    VecesMax    INT          NULL,
    VecesUsadas INT          NOT NULL CONSTRAINT DF_Pases_VecesUsadas DEFAULT(0),
    Estado      BIT          NOT NULL CONSTRAINT DF_Pases_Estado DEFAULT(1),
    CONSTRAINT FK_Pases_Socio FOREIGN KEY(IDSocio) REFERENCES dbo.Socios(IDSocio),
    CONSTRAINT FK_Pases_Tipo  FOREIGN KEY(IDTipo)  REFERENCES dbo.TiposPase(IDTipo)
);
GO

-- 1.6) PASES HISTORIAL
CREATE TABLE PasesHistorial(
    IdHist      INT IDENTITY(1,1) PRIMARY KEY,
    IDPase      INT          NOT NULL,
    IDSocio     INT          NOT NULL,
    IDTipo      INT          NOT NULL,
    FechaInicio DATE         NOT NULL,
    FechaFin    DATE         NOT NULL,
    VecesMax    INT          NULL,
    VecesUsadas INT          NOT NULL,
    Estado      BIT          NOT NULL,
    Accion      NVARCHAR(50) NOT NULL,   -- 'INSERT'/'UPDATE'/'VENCER', etc.
    FechaEvento DATETIME     NOT NULL CONSTRAINT DF_PasesHistorial_Fecha DEFAULT(GETDATE()),
    CONSTRAINT FK_PH_Pase  FOREIGN KEY(IDPase)  REFERENCES dbo.Pases(IDPase),
    CONSTRAINT FK_PH_Socio FOREIGN KEY(IDSocio) REFERENCES dbo.Socios(IDSocio),
    CONSTRAINT FK_PH_Tipo  FOREIGN KEY(IDTipo)  REFERENCES dbo.TiposPase(IDTipo)
);
GO

-- 1.7) CLASE MAESTRA
CREATE TABLE ClaseMaestra(
    IdClaseMaestra INT IDENTITY(1,1) PRIMARY KEY,
    Nombre         NVARCHAR(100) NOT NULL UNIQUE,
    Descripcion    NVARCHAR(200) NULL,
    Activa         BIT           NOT NULL CONSTRAINT DF_ClaseMaestra_Activa DEFAULT(1)
);
GO

-- 1.8) CLASE INSTANCIA
CREATE TABLE ClaseInstancia(
    IdClase        INT IDENTITY(1,1) PRIMARY KEY,
    IdClaseMaestra INT      NOT NULL,
    Fecha          DATE     NOT NULL,
    HoraInicio     TIME     NOT NULL,
    HoraFin        TIME     NOT NULL,
    Cupo           INT      NOT NULL CHECK (Cupo > 0),
    IdProfesor     INT      NULL,
    Activa         BIT      NOT NULL CONSTRAINT DF_ClaseInstancia_Activa DEFAULT(1),
    CONSTRAINT FK_CI_Maestra  FOREIGN KEY(IdClaseMaestra) REFERENCES dbo.ClaseMaestra(IdClaseMaestra),
    CONSTRAINT FK_CI_Profesor FOREIGN KEY(IdProfesor)     REFERENCES dbo.Profesores(IdProfesor)
);
GO

-- 1.9) INSCRIPCIONES
CREATE TABLE Inscripciones(
    IDInscripcion    INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio          INT          NOT NULL,
    IdClaseInstancia INT          NOT NULL,
    FechaAlta        DATETIME     NOT NULL CONSTRAINT DF_Inscripciones_FechaAlta DEFAULT(GETDATE()),
    CONSTRAINT FK_Ins_Socio          FOREIGN KEY(IDSocio)          REFERENCES dbo.Socios(IDSocio),
    CONSTRAINT FK_Ins_ClaseInstancia FOREIGN KEY(IdClaseInstancia) REFERENCES dbo.ClaseInstancia(IdClase),
    CONSTRAINT UQ_Inscripciones_SocioClase UNIQUE(IDSocio, IdClaseInstancia)
);
GO

-- 1.10) ASISTENCIAS
CREATE TABLE Asistencias(
    IDAsistencia INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio      INT          NOT NULL,
    FechaHoraIng DATETIME     NOT NULL CONSTRAINT DF_Asistencias_Fecha DEFAULT(GETDATE()),
    CONSTRAINT FK_Asistencias_Socio FOREIGN KEY(IDSocio) REFERENCES dbo.Socios(IDSocio)
);
GO

-- Índices útiles
CREATE INDEX IX_Pases_Socio_Fecha ON dbo.Pases(IDSocio, FechaInicio, FechaFin);
GO
CREATE INDEX IX_Asistencias_Socio_Fecha ON dbo.Asistencias(IDSocio, FechaHoraIng);
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





