/* ======================================================
   BASE DE DATOS: TPIGimnasio
   Motor: SQL Server
====================================================== */

DROP DATABASE IF EXISTS TPIGimnasio;
GO
CREATE DATABASE TPIGimnasio;
GO
USE TPIGimnasio;
GO

/* ============================
   TABLAS
============================ */

CREATE TABLE Socios (
    IDSocio   INT IDENTITY(1,1) PRIMARY KEY,
    DNI       CHAR(8) NOT NULL UNIQUE,
    Apellido  NVARCHAR(100) NOT NULL,
    Nombre    NVARCHAR(100) NOT NULL,
    Email     NVARCHAR(150) NOT NULL UNIQUE,
    Estado    BIT NOT NULL CONSTRAINT DF_Socios_Estado DEFAULT 1  -- 1=Activo, 0=Inactivo
);

CREATE TABLE TiposPase (
    IDTipo   INT IDENTITY(1,1) PRIMARY KEY,
    Nombre   VARCHAR(10) NOT NULL UNIQUE   -- 'DIARIO', 'OCHO', 'LIBRE'
);

CREATE TABLE Pases (
    IDPase       INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio      INT NOT NULL,
    IDTipo       INT NOT NULL,
    FechaInicio  DATE NOT NULL,
    FechaFin     DATE NOT NULL,
    VecesMax     INT NULL,         -- NULL para pase libre
    VecesUsadas  INT NOT NULL DEFAULT 0,
    Estado       BIT NOT NULL CONSTRAINT DF_Pases_Estado DEFAULT 1, -- 1=Activo, 0=Inactivo
    CONSTRAINT FK_Pases_Socio FOREIGN KEY (IDSocio) REFERENCES Socios(IDSocio) ON DELETE CASCADE,
    CONSTRAINT FK_Pases_Tipo  FOREIGN KEY (IDTipo)  REFERENCES TiposPase(IDTipo)
);

CREATE TABLE Clases (
    IDClase      INT IDENTITY(1,1) PRIMARY KEY,
    NombreClase  NVARCHAR(100) NOT NULL,
    CupoMaximo   INT NOT NULL CONSTRAINT CK_Clases_Cupo CHECK (CupoMaximo > 0),
    FechaHora    DATETIME NOT NULL
);

CREATE TABLE Inscripciones (
    IDInscripcion INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio       INT NOT NULL,
    IDClase       INT NOT NULL,
    FechaAlta     DATETIME NOT NULL DEFAULT(GETDATE()),
    CONSTRAINT UQ_Inscripcion UNIQUE (IDSocio, IDClase),
    CONSTRAINT FK_Ins_Socio FOREIGN KEY (IDSocio) REFERENCES Socios(IDSocio) ON DELETE CASCADE,
    CONSTRAINT FK_Ins_Clase FOREIGN KEY (IDClase) REFERENCES Clases(IDClase) ON DELETE CASCADE
);

CREATE TABLE Asistencias (
    IDAsistencia   INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio        INT NOT NULL,
    FechaHoraIng   DATETIME NOT NULL DEFAULT(GETDATE()),
    CONSTRAINT FK_Asis_Socio FOREIGN KEY (IDSocio) REFERENCES Socios(IDSocio) ON DELETE CASCADE
);
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

