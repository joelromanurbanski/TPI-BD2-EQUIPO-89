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

-- Asistencias mensuales (resumen del mes actual)
CREATE VIEW vw_AsistenciasMensuales AS
SELECT 
    s.IDSocio,
    s.Apellido + ' ' + s.Nombre AS Socio,
    COUNT(a.IDAsistencia) AS CantidadAsistencias,
    DATENAME(MONTH, GETDATE()) + ' ' + CAST(YEAR(GETDATE()) AS VARCHAR(4)) AS Periodo
FROM Socios s
LEFT JOIN Asistencias a 
       ON s.IDSocio = a.IDSocio
      AND MONTH(a.FechaHoraIng) = MONTH(GETDATE())
      AND YEAR(a.FechaHoraIng) = YEAR(GETDATE())
GROUP BY s.IDSocio, s.Apellido, s.Nombre;
GO
 -- Asistencia hoy :  liste todos los socios que fueron
CREATE VIEW vw_AsistenciasHoy AS
SELECT 
    A.IDAsistencia,
    A.IDSocio,
    A.FechaHoraIng,
    S.Apellido + ' ' + S.Nombre AS NombreCompleto
FROM Asistencias AS A
JOIN Socios AS S ON S.IDSocio = A.IDSocio
WHERE CONVERT(date, A.FechaHoraIng) = CONVERT(date, GETDATE());
GO
-- Socios Activos 
CREATE VIEW vw_SociosActivos AS
SELECT 
    IDSocio,
    DNI,
    Apellido,
    Nombre,
    Email
FROM Socios
WHERE Estado = 1;
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


CREATE PROCEDURE sp_ActivarNuevoPase
    @IDSocio INT,
    @IDTipo INT,
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    BEGIN TRY
        DECLARE @VecesMax INT;

        -- Validar socio activo
        IF NOT EXISTS (SELECT 1 FROM Socios WHERE IDSocio = @IDSocio AND Estado = 1)
        BEGIN
            PRINT 'Error: El socio no existe o no está activo.';
            RETURN;
        END

        -- Validar tipo de pase
        IF NOT EXISTS (SELECT 1 FROM TiposPase WHERE IDTipo = @IDTipo)
        BEGIN
            PRINT 'Error: Tipo de pase no válido.';
            RETURN;
        END

        -- Validar fechas
        IF @FechaInicio IS NULL OR @FechaFin IS NULL OR @FechaInicio > @FechaFin
        BEGIN
            PRINT 'Error: Fechas de inicio/fin inválidas.';
            RETURN;
        END

        -- Asignar cantidad de usos máximos según tipo
        SELECT @VecesMax = CASE UPPER(Nombre)
                              WHEN 'DIARIO' THEN 1
                              WHEN 'OCHO' THEN 8
                              WHEN 'LIBRE' THEN NULL
                           END
        FROM TiposPase
        WHERE IDTipo = @IDTipo;

        -- Desactivar otros pases vigentes del socio (solo debe haber uno activo)
        UPDATE Pases
        SET Estado = 0
        WHERE IDSocio = @IDSocio AND Estado = 1;

        -- Insertar nuevo pase
        INSERT INTO Pases (IDSocio, IDTipo, FechaInicio, FechaFin, VecesMax, VecesUsadas, Estado)
        VALUES (@IDSocio, @IDTipo, @FechaInicio, @FechaFin, @VecesMax, 0, 1);

        PRINT 'Nuevo pase activado correctamente.';
    END TRY

    BEGIN CATCH
        PRINT 'Error al activar el nuevo pase.';
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO
  CREATE PROCEDURE sp_ActivarNuevoSocio
    @DNI CHAR(8),
    @Apellido NVARCHAR(100),
    @Nombre NVARCHAR(100),
    @Email NVARCHAR(150)
AS
BEGIN
    BEGIN TRY
        -- Validaciones
        IF @DNI IS NULL OR @Apellido IS NULL OR @Nombre IS NULL OR @Email IS NULL
        BEGIN
            PRINT 'Error: Todos los campos son obligatorios.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Socios WHERE DNI = @DNI)
        BEGIN
            PRINT 'Error: Ya existe un socio con ese DNI.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Socios WHERE Email = @Email)
        BEGIN
            PRINT 'Error: Ya existe un socio con ese Email.';
            RETURN;
        END

        -- Inserción del socio
        INSERT INTO Socios (DNI, Apellido, Nombre, Email, Estado)
        VALUES (@DNI, @Apellido, @Nombre, @Email, 1);

        PRINT 'Socio registrado y activado correctamente.';
    END TRY

    BEGIN CATCH
        PRINT 'Error al registrar el nuevo socio.';
        PRINT ERROR_MESSAGE();
    END CATCH
END
GO

-- Buscar Socio por DNI
CREATE PROCEDURE sp_BuscarSocioPorDNI
    @DNI CHAR(8)
AS
BEGIN
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Socios WHERE DNI = @DNI)
        BEGIN
            PRINT 'No se encontró ningún socio con ese DNI.';
            RETURN;
        END

        SELECT 
            IDSocio,
            DNI,
            Apellido + ' ' + Nombre AS NombreCompleto,
            Email,
            CASE WHEN Estado = 1 THEN 'Activo' ELSE 'Inactivo' END AS Estado
        FROM Socios
        WHERE DNI = @DNI;

    END TRY
    BEGIN CATCH
        PRINT 'Error al buscar el socio.';
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


-- otra forma de registrar y activar un socio (acordarse el lugar de los parametros donde colocarlo):
EXEC sp_ActivarNuevoSocio 3,'carracedo','sebas','scarracedo@example.com';

-- asi se registra y activa un socio: 
EXEC sp_ActivarNuevoSocio 
    @DNI = '40205305',
    @Apellido = N'carracedo',
    @Nombre = N'sebas',
    @Email = N'scarra@example.com';
    -- asi se verifica que aparezcan todos :
SELECT * FROM Socios;

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




/* ============================
   MODIFICACIONES A LAS TABLAS
============================ */

ALTER TABLE Persona
ADD Direccion NVARCHAR(200),
    FechaNacimiento DATE,
    Email NVARCHAR(150),
    EstadoCivil NVARCHAR(50);
GO

-- Agregar columna Observaciones
ALTER TABLE Socios
ADD Observaciones NVARCHAR(300);
GO

-- Eliminar columnas que ahora están en Persona
ALTER TABLE Socios
DROP COLUMN Email;
GO 

ALTER TABLE Socios
DROP COLUMN FechaNacimiento;
GO

--Cambiar nombres a las tablas
EXEC sp_rename 'TiposPase', 'Pase';
GO

EXEC sp_rename 'Pases', 'PasePorSocio';
GO

--Cambiar nombre de columna
EXEC sp_rename 'PasesHistorial.FechaEvento', 'FechaRenovacion', 'COLUMN';
GO

USE TPIGimnasio;
GO
ALTER TABLE dbo.PasePorSocio
ADD CONSTRAINT CK_PPS_UsosNoSuperaMax
CHECK (VecesMax IS NULL OR VecesUsadas <= VecesMax);
GO

ALTER TABLE PasePorSocio ADD FechaRenovacion DATE NULL;
DROP TABLE PasesHistorial;

CREATE TABLE HistorialMedico (
    IdHistorial INT IDENTITY PRIMARY KEY,
    IdSocio INT NOT NULL,
    FechaControl DATE NOT NULL DEFAULT GETDATE(),
    TipoControl NVARCHAR(100) NOT NULL,
    Resultado NVARCHAR(200),
    Observaciones NVARCHAR(200),
    CONSTRAINT FK_HistorialMedico_Socio FOREIGN KEY (IdSocio)
        REFERENCES Socios(IdSocio)
);

ALTER TABLE Asistencias
DROP CONSTRAINT FK_Asistencias_Socio;

ALTER TABLE Asistencias
DROP COLUMN IdSocio;

ALTER TABLE Asistencias
ADD IdPase INT NOT NULL,
    CONSTRAINT FK_Asistencias_Pase FOREIGN KEY (IdPase)
        REFERENCES PasePorSocio(IdPase);

ALTER TABLE Inscripciones
ADD Estado NVARCHAR(20) NOT NULL DEFAULT 'Activa'
    CONSTRAINT CK_Inscripciones_Estado CHECK (Estado IN ('Activa', 'Cancelada', 'Cambiada'));

	USE TPIGimnasio;
GO

USE TPIGimnasio;
GO



