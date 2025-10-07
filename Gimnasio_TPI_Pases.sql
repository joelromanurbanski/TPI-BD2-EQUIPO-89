
/*
============================================================
  TPI - Base de Datos II
  Caso: GIMNASIO con Tipos de Pase (DIARIO, OCHO, LIBRE)
  Script unificado: Creación + Datos
  Motor: SQL Server
============================================================


/* ==========================================================
   1) TABLAS
========================================================== */
create database TPIGimnasio ;


CREATE TABLE dbo.Socios (
    IDSocio   INT IDENTITY(1,1) PRIMARY KEY,
    DNI       CHAR(8) NOT NULL UNIQUE,
    Apellido  NVARCHAR(100) NOT NULL,
    Nombre    NVARCHAR(100) NOT NULL,
    Email     NVARCHAR(150) NOT NULL UNIQUE,
    Estado    CHAR(1) NOT NULL CONSTRAINT CK_Socios_Estado CHECK (Estado IN ('A','I'))  -- A=Activo, I=Inactivo
);

CREATE TABLE dbo.TiposPase (
    IDTipo   INT IDENTITY(1,1) PRIMARY KEY,
    Nombre   VARCHAR(10) NOT NULL UNIQUE  -- 'DIARIO' | 'OCHO' | 'LIBRE'
);

CREATE TABLE dbo.Pases (
    IDPase       INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio      INT NOT NULL,
    IDTipo       INT NOT NULL,
    FechaInicio  DATE NOT NULL,
    FechaFin     DATE NOT NULL,
    VecesMax     INT NULL,         -- NULL para LIBRE
    VecesUsadas  INT NOT NULL DEFAULT 0,
    Estado       VARCHAR(10) NOT NULL DEFAULT 'ACTIVO' CONSTRAINT CK_Pases_Estado CHECK (Estado IN ('ACTIVO','VENCIDO','CANCELADO')),
    CONSTRAINT FK_Pases_Socio FOREIGN KEY (IDSocio) REFERENCES dbo.Socios(IDSocio) ON DELETE CASCADE,
    CONSTRAINT FK_Pases_Tipo FOREIGN KEY (IDTipo)  REFERENCES dbo.TiposPase(IDTipo)
);

-- Índice útil para buscar pase vigente rápido
CREATE INDEX IX_Pases_SocioFechas ON dbo.Pases(IDSocio, FechaInicio, FechaFin) INCLUDE(VecesMax, VecesUsadas, Estado, IDTipo);

CREATE TABLE dbo.Clases (
    IDClase      INT IDENTITY(1,1) PRIMARY KEY,
    NombreClase  NVARCHAR(100) NOT NULL,
    CupoMaximo   INT NOT NULL CONSTRAINT CK_Clases_Cupo CHECK (CupoMaximo > 0),
    FechaHora    DATETIME NOT NULL
);

CREATE TABLE dbo.Inscripciones (
    IDInscripcion INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio       INT NOT NULL,
    IDClase       INT NOT NULL,
    FechaAlta     DATETIME NOT NULL DEFAULT(GETDATE()),
    CONSTRAINT UQ_Inscripcion UNIQUE (IDSocio, IDClase),
    CONSTRAINT FK_Ins_Socio FOREIGN KEY (IDSocio) REFERENCES dbo.Socios(IDSocio) ON DELETE CASCADE,
    CONSTRAINT FK_Ins_Clase FOREIGN KEY (IDClase) REFERENCES dbo.Clases(IDClase) ON DELETE CASCADE
);

CREATE TABLE dbo.Asistencias (
    IDAsistencia   INT IDENTITY(1,1) PRIMARY KEY,
    IDSocio        INT NOT NULL,
    FechaHoraIng   DATETIME NOT NULL DEFAULT(GETDATE()),
    CONSTRAINT FK_Asis_Socio FOREIGN KEY (IDSocio) REFERENCES dbo.Socios(IDSocio) ON DELETE CASCADE
);

