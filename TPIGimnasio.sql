-- ======================================================
--  TPIGimnasio
-- ======================================================

-- 0) RECREAR BASE
IF DB_ID('TPIGimnasio') IS NOT NULL
BEGIN
    ALTER DATABASE TPIGimnasio SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TPIGimnasio;
END
GO
CREATE DATABASE TPIGimnasio;
GO
USE TPIGimnasio;
GO

-- ======================================================
-- 1) TABLAS
-- ======================================================

-- 1.1) PERSONA
CREATE TABLE dbo.Persona(
    IdPersona INT IDENTITY(1,1) PRIMARY KEY,
    DNI       CHAR(8)        NOT NULL UNIQUE,
    Apellido  NVARCHAR(100)  NOT NULL,
    Nombre    NVARCHAR(100)  NOT NULL
);
GO

-- 1.2) SOCIOS
CREATE TABLE dbo.Socios(
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
CREATE TABLE dbo.Profesores(
    IdProfesor   INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona    INT             NOT NULL,
    Especialidad NVARCHAR(100)   NULL,
    Estado       BIT             NOT NULL CONSTRAINT DF_Profesores_Estado DEFAULT(1),
    FechaAlta    DATETIME        NOT NULL CONSTRAINT DF_Profesores_FechaAlta DEFAULT(GETDATE()),
    CONSTRAINT FK_Profesores_Persona FOREIGN KEY(IdPersona) REFERENCES dbo.Persona(IdPersona)
);
GO

-- 1.4) TIPOS DE PASE
CREATE TABLE dbo.TiposPase(
    IDTipo  INT IDENTITY(1,1) PRIMARY KEY,
    Nombre  NVARCHAR(100) NOT NULL UNIQUE,
    Precio  DECIMAL(10,2) NOT NULL CONSTRAINT DF_TiposPase_Precio DEFAULT(0)
);
GO

-- 1.5) PASES
CREATE TABLE dbo.Pases(
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
CREATE TABLE dbo.PasesHistorial(
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
CREATE TABLE dbo.ClaseMaestra(
    IdClaseMaestra INT IDENTITY(1,1) PRIMARY KEY,
    Nombre         NVARCHAR(100) NOT NULL UNIQUE,
    Descripcion    NVARCHAR(200) NULL,
    Activa         BIT           NOT NULL CONSTRAINT DF_ClaseMaestra_Activa DEFAULT(1)
);
GO

-- 1.8) CLASE INSTANCIA
CREATE TABLE dbo.ClaseInstancia(
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
CREATE TABLE dbo.Inscripciones(
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
CREATE TABLE dbo.Asistencias(
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
  P.IDPase,
  S.IDSocio,
  S.Apellido + ', ' + S.Nombre AS Socio,
  TP.Nombre AS TipoPase,
  P.FechaFin,
  DATEDIFF(DAY, CAST(GETDATE() AS DATE), P.FechaFin) AS DiasRestantes
FROM Pases P
JOIN Socios S ON S.IDSocio = P.IDSocio
JOIN TiposPase TP ON TP.IDTipo = P.IDTipo
WHERE P.Estado = 1
  AND P.FechaFin >= CAST(GETDATE() AS DATE)
  AND P.FechaFin <= DATEADD(DAY, 7, CAST(GETDATE() AS DATE));
GO

-- Pases vigentes (activos hoy)
CREATE VIEW vw_PasesVigentes AS
SELECT 
  P.IDPase,
  P.IDSocio,
  S.Apellido + ' ' + S.Nombre AS NombreCompleto,
  TP.Nombre AS TipoPase,
  P.FechaInicio,
  P.FechaFin,
  P.VecesMax,
  P.VecesUsadas,
  CASE 
    WHEN P.VecesMax IS NULL THEN NULL
    ELSE (P.VecesMax - P.VecesUsadas)
  END AS UsosRestantes
FROM Pases AS P
JOIN Socios S  ON S.IDSocio = P.IDSocio
JOIN TiposPase TP ON TP.IDTipo = P.IDTipo
WHERE P.Estado = 1
  AND CAST(GETDATE() AS DATE) BETWEEN P.FechaInicio AND P.FechaFin;
GO

-- Clases sin cupos disponibles
CREATE VIEW vw_ClasesSinCupos AS
SELECT 
    c.IDClase,
    c.NombreClase,
    c.CupoMaximo,
    COUNT(i.IDInscripcion) AS Inscritos,
    c.FechaHora
FROM Clases c
LEFT JOIN Inscripciones i ON i.IDClase = c.IDClase
GROUP BY c.IDClase, c.NombreClase, c.CupoMaximo, c.FechaHora
HAVING COUNT(i.IDInscripcion) >= c.CupoMaximo;
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

Create Procedure sp_RegistrarAsistencia 
@IdSocio int, 
@FechaHora DATETIME=null as
Begin 
	Begin Try
	IF @FechaHora is null set @FechaHora=GETDATE();

	Declare @IdPase int,@IdTipo int,@VecesMax int,@VecesUsadas int;

	-- Buscamos un pase vigente (activo y dentro de las fechas)
	Select Top 1
		@IdPase=IDPase,
		@IdTipo=IDTipo,
		@VecesMax=VecesMax,
		@VecesUsadas=VecesUsadas
	From Pases
	Where IDSocio=@IdSocio
	and Estado=1 and cast(@FechaHora as DATE) Between FechaInicio and FechaFin
	Order By FechaFin asc;

	-- Si no se encontró ningún pase
	If @IdPase is null
	Begin
		Print 'No hay pase vigente para este socio.';
		Return;
	End

	 -- Si tiene tope y ya no tiene usos disponibles
	 If @VecesMax is not null and @VecesUsadas>=@VecesMAx
	 Begin 
		Print 'El pase ya no tiene usos disponibles';
		Return;
	End

	 -- Si el pase es diario y ya tiene una asistencia hoy
	 If @IdTipo=1 and Exists(
		Select 1 From Asistencias
		Where IDSocio=@IdSocio
		and Convert(date,FechaHoraIng)=convert(date,@FechaHora))
	Begin
		Print 'El pase ya fue usado hoy.';
		Return;
	End

	Begin Transaction;

	Insert Into Asistencias(IDSocio,FechaHoraIng)
	Values(@IdSocio,@FechaHora);

	 -- Si el pase tiene límite, sumamos 1 uso
	 If @VecesMax is not null
	 Update Pases
	 Set VecesUsadas=VecesUsadas+1
	 Where IDPase=@IdPase;

	 -- Desactivamos el pase si se quedó sin usos o ya venció
	 Update Pases
	 Set Estado=0
	 Where IDPase=@IdPase
	 and((VecesMax is not null and VecesUsadas>=VecesMax)
		or(cast(@FechaHora as DATE)>FechaFin)
	);
	Commit Transaction;

	Print 'Asistencia registrada correctamente.';

	End Try

	Begin Catch
	RollBack Transaction;
	Print 'Error al registrar asistencia.';
    Print ERROR_MESSAGE(); 
  END CATCH
END
GO

Create Procedure sp_AsistenciasMensual 
@Anio int, 
@Mes int as
Begin
	Begin Try
		Declare @AnioActual int = YEAR(GETDATE());
		If @Anio<>@AnioActual
		Begin
		Print 'Año invalido. Solo se permite el año actual.';
		Return;
	End
	If @Mes<1 or @Mes>12
	Begin
	Print 'Mes invalido.';
	Return;
	End

DECLARE @Desde DATE = CAST(CAST(@Anio AS CHAR(4)) + 
RIGHT('0'+CAST(@Mes AS VARCHAR(2)),2) + '01' AS DATE);
DECLARE @Hasta DATE = DATEADD(MONTH, 1, @Desde);

Select S.IDSocio, S.Apellido+' '+S.Nombre as Socio, 
COUNT(A.IDAsistencia) as CantidadAsistencias,
Min(A.FechaHoraIng) as PrimeraASistencia,
Max(A.FechaHoraIng) as UltimaASistencia
From Socios S
Left Join Asistencias A on A.IDSocio=S.IDSocio
and A.FechaHoraIng>=@Desde and A.FechaHoraIng<@Hasta
Group By S.IDSocio,S.Apellido,S.Nombre
Order By CantidadAsistencias Desc;

End Try

Begin Catch 
Print 'Error al obetener el resumen mensual.';
Print Error_Message();
End Catch
End
Go

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
            c.IDClase,
            c.NombreClase,
            c.CupoMaximo,
            COUNT(i.IDInscripcion) AS Inscriptos,
            (c.CupoMaximo - COUNT(i.IDInscripcion)) AS LugaresDisponibles,
            c.FechaHora
        FROM Clases c
        LEFT JOIN Inscripciones i ON i.IDClase = c.IDClase
        GROUP BY c.IDClase, c.NombreClase, c.CupoMaximo, c.FechaHora
        HAVING COUNT(i.IDInscripcion) < c.CupoMaximo
        ORDER BY c.FechaHora;

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
go
Create Trigger tr_Socio_NoRepetirDNI on Socios
After Insert
As
If Exists(Select 1 From inserted i 
   Join Socios s on s.DNI=i.DNI and s.IDSocio<>i.IDSocio)
Begin 
	Raiserror('El DNI ya existe.',16,1);
	Rollback Transaction;
End;
Go

Create Trigger tr_BajaLogicaSocios
On Socios
after Update
As
-- Solo actua si se cambio Estado a 0
IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.IdSocio=d.IdSocio 
		   WHERE i.Estado=0 AND ISNULL(d.Estado,1)<>0)
Begin
  Update p
    Set p.Estado = 0
  From Pases p
  Inner Join inserted i on i.IdSocio = p.IdSocio
  Where i.Estado = 0 AND p.Estado = 1;
End;
Go

Create Trigger tr_Pases_Vencidos On Pases
After Update
As
Update p
Set p.Estado = 0
From Pases p
Where p.Estado = 1
  And p.FechaFin < GETDATE();
Go
--TR_Pases_AI Objetivo: desactivar automáticamente cualquier otro pase vigente que tenga el socio cuando se inserta un nuevo pase.
CREATE TRIGGER TR_Pases_AI
ON Pases
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Pases
    SET Estado = 0
    WHERE IDSocio IN (SELECT IDSocio FROM inserted)
      AND IDPase NOT IN (SELECT IDPase FROM inserted)
      AND Estado = 1;

    PRINT 'Se desactivaron otros pases vigentes del socio al crear uno nuevo.';
END;
GO

--TR_Pases_Vencidos Objetivo: actualizar automáticamente el campo Estado de los pases vencidos
 
CREATE TRIGGER TR_Actualizar_Pases_Vencidos
ON Pases
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Pases
    SET Estado = 0
    WHERE FechaFin < CAST(GETDATE() AS DATE)
      AND Estado = 1;

    PRINT 'Se actualizaron los pases vencidos.';
END;
GO
--TR_Pases_ValidacionGeneral Objetivo: evitar que se inserten o actualicen pases con fechas inconsistentes (por ejemplo, FechaFin anterior a FechaInicio).
CREATE TRIGGER TR_Pases_ValidacionGeneral
ON Pases
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que las fechas sean correctas
    IF EXISTS (
        SELECT 1 
        FROM inserted
        WHERE FechaFin <= FechaInicio
    )
    BEGIN
        PRINT 'Error: la fecha de fin debe ser posterior a la fecha de inicio.';
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Si está todo bien, realizar la operación normalmente
    INSERT INTO Pases (IDSocio, IDTipo, FechaInicio, FechaFin, VecesMax, VecesUsadas, Estado)
    SELECT IDSocio, IDTipo, FechaInicio, FechaFin, VecesMax, VecesUsadas, Estado
    FROM inserted;

    PRINT 'Validación correcta: pase insertado o actualizado exitosamente.';
END;
GO

--TR_Asistencias_AI: Objetivo: Evita registrar dos asistencias el mismo día para el mismo socio.

CREATE TRIGGER TR_Asistencias_AI
ON Asistencias
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM Asistencias A
        JOIN inserted I ON A.IDSocio = I.IDSocio
        WHERE CONVERT(DATE, A.FechaHoraIng) = CONVERT(DATE, I.FechaHoraIng)
          AND A.IDAsistencia <> I.IDAsistencia
    )
    BEGIN
        RAISERROR('Error: ya existe una asistencia registrada para este socio en el día.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

--TR_Asistencias_BI: Objetivo: Evita insertar una asistencia si el socio no está activo.

CREATE TRIGGER TR_Asistencias_BI
ON Asistencias
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted I
        JOIN Socios S ON S.IDSocio = I.IDSocio
        WHERE S.Estado = 0
    )
    BEGIN
        RAISERROR('Error: el socio no está activo. No se puede registrar asistencia.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Si pasa la validación, se inserta normalmente
    INSERT INTO Asistencias (IDSocio, FechaHoraIng)
    SELECT IDSocio, FechaHoraIng FROM inserted;
END;
GO

-- TR_RegistroAsistenciaPorInscripcion: Objetivo: Inserta automáticamente una asistencia cuando un socio se inscribe a una clase.

CREATE TRIGGER TR_RegistroAsistenciaPorInscripcion
ON Inscripciones
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Asistencias (IDSocio, FechaHoraIng)
    SELECT IDSocio, GETDATE()
    FROM inserted;

    PRINT 'Asistencia registrada automáticamente al inscribirse en una clase.';
END;
GO

--TR_ControlCuposInscripciones: Objetivo: Impide que se inscriban más socios que el cupo máximo de la clase.

CREATE TRIGGER TR_ControlCuposInscripciones
ON Inscripciones
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM ClaseInstancia C
        JOIN (
            SELECT IdClaseInstancia, COUNT(*) AS TotalInscriptos
            FROM Inscripciones
            GROUP BY IdClaseInstancia
        ) AS X ON C.IdClase = X.IdClaseInstancia
        WHERE X.TotalInscriptos > C.Cupo
    )
    BEGIN
        RAISERROR('Error: no se puede inscribir, se alcanzó el cupo máximo de la clase.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
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
