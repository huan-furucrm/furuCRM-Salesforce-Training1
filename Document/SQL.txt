------create table Accounts-------

CREATE TABLE Accounts (
 External_ID numeric primary key,
	Name varchar(10),
	AccountNumber numeric(5),
	Type varchar,
	First_Name varchar(18),
	Last_Name varchar(18),
	Mail varchar,
	Phone varchar,
	Rating varchar,
	NumberOfEmployees numeric,
	CreatedById varchar,
	OperatingHoursId date
)

--------SQL------------------
select * from Accounts