

DROP SCHEMA public CASCADE;

create schema public;

create or replace function public.fn_current_user_id() returns int as $$
  select coalesce (nullif(current_setting('jwt.claims.user_id', true), '')::int,1); --to do in PROD change this to error if the current setting is NULL
$$ language sql stable set search_path from current;

comment on function  public.fn_current_user_id() is
  E'@omit\nHandy method to get the current user ID for use in RLS policies, etc; in GraphQL, use `currentUser{id}` instead.';
 
 
 
create or replace function public.fn_set_modified_fields() returns trigger as $$
begin
  new."DateModified" := current_timestamp;
  new."ModifiedBy" := fn_current_user_id();
  return new;
end;
$$ language plpgsql;


 
create type public.ApptType as enum (
  'Appointment',
  'Customer Sale',
  'Walk In Sale'
);


create type public.Permission as enum (
  'AnonCustomer',  -- great for assistants or people who need to know on an informed or consulted basis
  'ReadOnly',  -- great for assistants or people who need to know on an informed or consulted basis
  'ReadWrite',  -- General Users of the system
  'Administrator'  -- People Accountable for the system
);


------------------------
--SECURITY
------------------------

-- public."Users" definition

-- Drop table

-- DROP TABLE public."Users";

CREATE TABLE public."Users" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL DEFAULT 1,
	"Permission" public.permission,
	"FirstName" text NULL,
	"LastName" text NULL,
	"OpenIdUrl" text NULL,
	"UserStatus" text NULL,
	"IsClientAdmin" bool NULL,
	"IsApproved" bool NULL,
	"Active" bool NOT NULL DEFAULT True,
	"CreatedBy" int not null default 1,
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT User_pkey PRIMARY KEY ("Id")
);

comment on table  public."Users" is 'Public information about a user’s account.';
comment on column public."Users"."Id" is 'The id of the user also associated with users private account.';
comment on column public."Users"."LocaleId" is 'The users location.';
comment on column public."Users"."Permission" is 'The users permission: Anonymous, R/O, R/W or Admin.';
comment on column public."Users"."FirstName" is 'The users last name.';	
comment on column public."Users"."LastName" is 'The users last name.';
comment on column public."Users"."OpenIdUrl" is 'The Open Id URL for authorization and authentication.';
comment on column public."Users"."UserStatus" is 'The users status for joining the system.';
comment on column public."Users"."IsClientAdmin" is 'The user can approve new users.';
comment on column public."Users"."IsApproved" is 'The records last modified date.';
comment on column public."Users"."Active" is 'The user is active (not deactivated).';
comment on column public."Users"."CreatedBy" is 'The user who first created the record.';
comment on column public."Users"."ModifiedBy" is 'The records last modified user.';
comment on column public."Users"."DateCreated" is 'The records created date.';
comment on column public."Users"."DateModified" is 'The records last modified date.';


create trigger tr_User_updated before update
  on public."Users"
  for each row
  execute procedure public.fn_set_modified_fields();
 

 

-- public."Locales" definition

-- Drop table
-- Drop table

-- DROP TABLE public."Locales";

CREATE TABLE public."Locales" (
	"Id" serial4 NOT NULL,
	"Address" text NULL,
	"Suburb" text NULL,
	"PostCode" text NULL,
	"State" text NULL,
	"TaxRate" int4 NOT NULL default 10,
	"DayStart" int4 NOT NULL default 9,
	"DayEnd" int4 NOT NULL default 17,
	"HourSegment" int4 NOT NULL default 2,
	"ApptDuration" int4 NOT NULL default 30,
	"ReceiptPrinter" text NULL,
	"CashDrawerChar" text NULL,
	"SkinTheme" text NULL,
	"ShowAuditField" bool NULL DEFAULT false,
	"Active" bool NULL DEFAULT true,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT Location_pkey PRIMARY KEY ("Id")
);


create trigger tr_Location_updated before update
  on public."Locales"
  for each row
  execute procedure public.fn_set_modified_fields();


 
drop TABLE private."UserAccounts";
drop schema private;
create schema private;


CREATE EXTENSION if not exists CITEXT;


CREATE TABLE private."UserAccounts" (
	"Id" serial4 primary key references public."Users"("Id") on delete cascade,
	"Email" citext not null unique check (length("Email") <= 255 and ("Email" ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')),
	"PasswordHash" text NOT NULL
);
comment on table  private."UserAccounts" is 'Private information about a user’s account.';
comment on column private."UserAccounts"."Id" is 'The id of the user associated with this account.';
comment on column private."UserAccounts"."Email" is 'The email address of the user.';
comment on column private."UserAccounts"."PasswordHash" is 'An opaque hash of the user’s password.';




 
ALTER SEQUENCE public."Users_Id_seq" RESTART 1;

--select * from public."Users"
INSERT INTO public."Users" ("LocaleId","Permission","FirstName","LastName","OpenIdUrl","UserStatus","Active","IsClientAdmin","IsApproved","CreatedBy") VALUES
(1,'Administrator','Admin','Admin','http://openid.net',NULL,true,true,true,1);


ALTER SEQUENCE private."UserAccounts_Id_seq" RESTART 1;
--select * from private."UserAccounts"
INSERT INTO private."UserAccounts" ("Id","Email","PasswordHash") VALUES
(1,'info@AppointmentsBook.com','dfgfd346');

	
ALTER SEQUENCE public."Locales_Id_seq" RESTART 1;
INSERT INTO public."Locales" ("Address","Suburb","PostCode","State", "TaxRate","DayStart", "DayEnd","HourSegment", "ApptDuration", "ReceiptPrinter","CashDrawerChar","SkinTheme", "UserId") VALUES ('PO Box 3052','St Leonards','2065','NSW', 10, 9,17,2,30, 'Microsoft XPS Document Writer','A', '.', 1);

	
-- I need to insert into the User table to create a default Location record that I can then use its ID to insert into the User table.
alter table public."Users" add CONSTRAINT FK_User_Location FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id");


 


--------------------------------
--TABLES
--------------------------------
--

-- public."Settings" definition

-- Drop table

-- DROP TABLE public."Settings";

CREATE TABLE public."Settings" (
	"Id" serial NOT NULL,
	"SettingProperty" text NOT NULL,
	"Description" text NOT NULL,
	CONSTRAINT Settings_pkey PRIMARY KEY ("Id")
);

comment on table  public."Settings" is 'Global application settings that affect all locations.';
comment on column public."Settings"."Id" is 'The setting id.';
comment on column public."Settings"."SettingProperty" is 'The setting value.';
comment on column public."Settings"."Description" is 'The setting description.';



CREATE TABLE public."Customers" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL DEFAULT 1,
	"MembershipId" text NULL,
	"TitleSettingId" int4 NOT NULL DEFAULT 9,
	"FirstName" text NULL check(length("FirstName") <= 40),
	"LastName" text NULL check(length("LastName") <= 60),
	--FullNameTxtSearchToken TSVECTOR,
	"Occupation" text NULL,
	"IndustrySettingId" int4 NULL,
	"Phone" text NULL,
	"Mobile" text NULL,
	"Email" citext NULL check(length("Email") <= 255 and ("Email" ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')),
	"Sex" text NOT NULL DEFAULT '',
	"VOIPPhone" text NULL,
	"Address1" text NULL,
	"Address2" text NULL,
	"Suburb" text NULL,
	"State" text NULL,
	"PostCode" text NULL,
	"CountrySettingId" int4 NULL,
	"DateOfBirth" Date NULL,
	"Active" bool NOT NULL DEFAULT true,
	"Misc" text NULL,
	"NoMail" bool NOT NULL DEFAULT false,
	"NoTextMessage" bool NULL DEFAULT false,
	"AttachmentURLsCSV" text NULL,
	"PictureURLsCSV" text NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT Customer_pkey PRIMARY KEY ("Id"),	
	CONSTRAINT FK_Customer_Location FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id"),
	CONSTRAINT FK_CustomerTitle_Settings FOREIGN KEY ("TitleSettingId") REFERENCES public."Settings"("Id"),
	CONSTRAINT FK_CustomerCountry_Settings FOREIGN KEY ("CountrySettingId") REFERENCES public."Settings"("Id"),
	CONSTRAINT FK_CustomerInd_Settings FOREIGN KEY ("IndustrySettingId") REFERENCES public."Settings"("Id")
);

CREATE INDEX customer_title_idx ON public."Customers" USING btree ("TitleSettingId");
--CREATE INDEX customer_firstand"LastName"_idx ON public."Customers" USING btree ("FirstName", "LastName");  -- because " WHERE Field ilike '%abc%' " searches dont use indexes I use a TriGram FullText Search 
--CREATE INDEX customer_mobile_idx ON public."Customers" USING btree (Mobile); -- the Mobile field is a great index by itself
CREATE INDEX customer_postcode_idx ON public."Customers" USING btree ("PostCode");


CREATE EXTENSION pg_trgm;
CREATE EXTENSION btree_gin;
CREATE INDEX CustFirstNameTxtSearch_idx ON public."Customers" USING gin("FirstName");
CREATE INDEX CustLastNameTxtSearch_idx ON public."Customers" USING gin("LastName");

--CREATE INDEX "irstName_name_special_idx ON "FirstName" (name COLLATE "C");
--CREATE INDEX LastName_name_special_idx ON "LastName" (name COLLATE "C");


create trigger tr_Customer_updated before update
  on public."Customers"
  for each row
  execute procedure public.fn_set_modified_fields();
 
 

--create or replace function public.fn_Populate_FullNameTxtSearchToken()
--  returns trigger
--as
--$$
--begin
--  new.FullNameTxtSearchToken := to_tsvector(new."FirstName" || ' ' || new."LastName"));
--  return new;
--end;    
--$$ language plpgsql;
--
--create trigger tr_Update_FullNameTxtSearchToken
--  before update or insert on Customer
--  for each row execute procedure fn_Populate_FullNameTxtSearchToken();


-- public."DailyNotes" definition

-- Drop table

-- DROP TABLE public."DailyNotes";

CREATE TABLE public."DailyNotes" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NULL,
	"Note" text NULL,
	"DailyDate" Date NULL,
	CONSTRAINT DailyNote_pkey PRIMARY KEY ("Id"),	
	CONSTRAINT FK_DailyNote_Location FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id")
);
CREATE INDEX dailynote_dailydateandLocationId_idx ON public."DailyNotes" USING btree ("DailyDate", "LocaleId");


-- public."DescOrders" definition

-- Drop table

-- DROP TABLE public."DescOrders";

CREATE TABLE public."DescOrders" (
	"Id" serial4 NOT NULL,
	"Description" text NOT NULL,
	"Order" int4 NOT NULL,
	"IsVisible" bool NOT NULL DEFAULT true,
	CONSTRAINT DescOrder_pkey PRIMARY KEY ("Id")
);


-- public."GS" definition

-- Drop table

-- DROP TABLE public."GoodServices";

CREATE TABLE public."GoodServices" (
	"Id" serial4 NOT NULL,
	"Title" text NOT NULL,
	--GSNameTxtSearchToken TSVECTOR,
	"Description" text NULL,
	"Duration" text NOT NULL default '00:00',
	"Price" decimal(12,2) NOT NULL DEFAULT 0,
	"Code" text NULL,
	"BarCode" text NULL,
	"IsApptDefault" bool NOT NULL DEFAULT FALSE,
	"Active" bool NOT NULL DEFAULT true,
	"Color" text NOT NULL  DEFAULT '#000000',
	"IsService" bool NULL DEFAULT FALSE,
	"IsExpense" bool NULL DEFAULT FALSE,
	"IsTaxable" bool NULL DEFAULT TRUE,
	"Tax" int4 NOT null default 10,
	"PictureURLsCSV" text NULL,
	"AttachmentURLsCSV" text NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT GoodService_pkey PRIMARY KEY ("Id")
);
CREATE INDEX GoodService_barcode_idx ON public."GoodServices" USING btree ("BarCode");
CREATE INDEX GoodService_code_idx ON public."GoodServices" USING btree ("Code");

CREATE INDEX GoodServiceTitleTxtSearchToken_idx ON public."GoodServices" USING gin("Title");

create trigger tr_GoodService_updated before update
  on public."GoodServices"
  for each row
  execute procedure public.fn_set_modified_fields();

--
--create or replace function public.fn_Populate_GSNameTxtSearchToken()
--  returns trigger
--as
--$$
--begin
--  new.GSNameTxtSearchToken := to_tsvector(new.Title);
--  return new;
--end;    
--$$ language plpgsql;
--
--create trigger tr_Update_GSNameTxtSearchToken
--  before update or insert on GS
--  for each row execute procedure fn_Populate_GSNameTxtSearchToken();



-- public."Resources" definition

-- Drop table

-- DROP TABLE public."Resources";

CREATE TABLE public."Resources" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL DEFAULT 1,
	"OrderId" int4 NULL,
	"MembershipId" text NULL,
	"DisplayName" text NOT NULL,
	"TitleSettingId" int4 NOT NULL DEFAULT 8,
	"FirstName" text NULL,
	"LastName" text NULL,
	"Phone" text NULL,
	"Mobile" text NULL,
	"Email" text NULL,
	"VoipPhone" text NULL,
	"Address1" text NULL,
	"Address2" text NULL,
	"Suburb" text NULL,
	"State" text NULL,
	"PostCode" text NULL,	
	"CountrySettingId" int NOT NULL default 1712,
	"Sex" text NULL,
	"DateOfBirth" Date NULL,
	"Active" bool NOT NULL DEFAULT true,
	"BillingLastTimeActiveOff" timestamptz NULL,
	"BillingLastTimeActiveOn" timestamptz NULL,  
	"Misc" text NULL,
	"DefaultGoodServicesCSV" text NULL,
	"PictureURLsCSV" text NULL,
	"AttachmentURLsCSV" text NULL,
	"Leave" timestamptz NULL,
	"ReturnFromLeave" timestamptz NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT Resource_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_Resource_Location FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id"),
	CONSTRAINT FK_Title_Settings FOREIGN KEY ("TitleSettingId") REFERENCES public."Settings"("Id"),
	CONSTRAINT FK_Country_Settings FOREIGN KEY ("CountrySettingId") REFERENCES public."Settings"("Id")
);


CREATE INDEX ResFirstNameTxtSearch_idx ON public."Resources" USING gin("FirstName");
CREATE INDEX ResLastNameTxtSearch_idx ON public."Resources" USING gin("LastName");

create trigger tr_Resource_updated before update
  on public."Resources"
  for each row
  execute procedure public.fn_set_modified_fields();

 
	-- If Bill on 1st Mar, scan 3 Resources, if DeActive 31st Mar, we scan 0 on 1st Apr, then we know If DeActive > GetDate - 1 Month = $0. 
	-- If 1st May and we scan 0, the LastDateOn will be 1st or 2nd Apr and LastDateOff is 31st Mar (IF LastDateOn - LastDateOff < 1 month = $$$)
	




-- public."LetterHeads" definition

-- Drop table

-- DROP TABLE public."LetterHeads";

CREATE TABLE public."LetterHeads" (
	"Id" serial4 NOT NULL,
	"Text" text NULL,
	"Font" text NOT NULL,
	"Size" int4 NOT NULL,
	"Height" int4 NOT NULL,
	"Alignment" int4 NOT NULL,
	"Position" int4 NOT NULL,
	"Bold" bool NOT NULL,
	"Italic" bool NOT NULL,
	"Underline" bool NOT NULL,
	CONSTRAINT "LetterHead_pkey" PRIMARY KEY ("Id")
);


-- public."Letters" definition

-- Drop table

-- DROP TABLE public."Letters";

CREATE TABLE public."Letters" (
	"Id" serial4 NOT NULL,
	"Title" text NOT NULL,
	"Subject" text NULL,
	"Body" text NULL,
	"IsDeleted" bool NOT NULL DEFAULT false,
	CONSTRAINT Letter_pkey PRIMARY KEY ("Id")
);



-- DROP TABLE public."SMSBatchs";

CREATE TABLE public."SMSBatchs" (
	"Id" serial4 NOT NULL,
	"LetterId" int4 NOT NULL,
	"SentDate" timestamptz NULL,
	"DeliveryReport" bool NOT NULL,
	CONSTRAINT SMSBatchs_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_smsBatch_LetterID FOREIGN KEY ("LetterId") REFERENCES public."Letters"("Id")
);



-- DROP TABLE public.SMSDelivery;

CREATE TABLE public."SMSDeliverys" (
	"Id" serial4 NOT NULL,
	"SMSBatchId" int4 NOT NULL,
	"CustomerId" int4 NOT NULL,
	"ResourceId" int4 NOT NULL,
	"IsAppConfirmation" bool NOT NULL,
	"AppTimeId" int4 NOT NULL,
	"ErrorCode" int4 NULL,
	CONSTRAINT SMSDeliveries_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_smsDelivery_smsBatch FOREIGN KEY ("SMSBatchId") REFERENCES public."SMSBatchs"("Id")
);


-- DROP TABLE public."SMSReplys";

CREATE TABLE public."SMSReplys" (
	"Id" serial4 NOT NULL,
	"SMSDeliveryId" int4 NOT NULL,
	"ReportStatus" int4 NOT NULL,
	"Delay" int4 NOT NULL,
	"Reply" text NULL,
	CONSTRAINT SMSReplies_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_smsReply_smsDelivery FOREIGN KEY ("SMSDeliveryId") REFERENCES public."SMSDeliverys"("Id")
);



-- public."Tasks" definition

-- Drop table

-- DROP TABLE public."Tasks";

CREATE TABLE public."Tasks" (
	"Id" serial4 NOT NULL,
	"Description" text NULL,
	"IsDeleted" bool NOT NULL,
	CONSTRAINT Task_pkey PRIMARY KEY ("Id")
);





-- public."AppTimes" definition

-- Drop table

-- DROP TABLE public."AppTimes";

CREATE TABLE public."AppTimes" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL DEFAULT 1,
	"StartTime" timestamptz NULL,
	"EndTime" timestamptz NULL,
	"ReminderTime" timestamptz NULL,
	"ReminderSound" bool NULL,
	"Color" text NULL,
	"TaskId" int4 NULL,
	"CustomTask" text NULL,
	"ApptType" public.ApptType,
	"RepeatApptSeriesId" int4 NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT AppTime_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_AppTime_Task FOREIGN KEY ("TaskId") REFERENCES public."Tasks"("Id"),	
	CONSTRAINT FK_AppTime_Location FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id")
);
CREATE INDEX apptime_startandendtime_idx ON public."AppTimes" USING btree ("StartTime","EndTime");
CREATE INDEX apptime_LocationId_idx ON public."AppTimes" ("LocaleId");
CREATE INDEX apptime_LocationIdplusstartend_idx ON public."AppTimes" ("LocaleId","StartTime","EndTime");


create trigger tr_AppTime_updated before update
  on public."AppTimes"
  for each row
  execute procedure public.fn_set_modified_fields();

 
-- public."Cancellations" definition

-- Drop table

-- DROP TABLE public."Cancellations";

CREATE TABLE public."Cancellations" (
	"Id" serial4 NOT NULL,
	"CancelledNotNoShow" bool NOT NULL,
	"CustomerId" int4 NOT NULL,
	"ResourceId" int4 NOT NULL,
	"DateCancelled" Date NOT NULL,
	"AppointmentDate" Date NOT NULL,
	CONSTRAINT Cancellation_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_Cancellations_Customer FOREIGN KEY ("CustomerId") REFERENCES public."Customers"("Id"),
	CONSTRAINT FK_Cancellations_Resource FOREIGN KEY ("ResourceId") REFERENCES public."Resources"("Id")
);


-- public."CustomerSpreadsheets" definition

-- Drop table

-- DROP TABLE public."CustomerSpreadsheets";

CREATE TABLE public."CustomerSpreadsheets" (
	"Id" serial4 NOT NULL,
	"CustomerId" int4 NOT NULL,
	"A" text NULL,
	"B" text NULL,
	"C" text NULL,
	"D" text NULL,
	"E" text NULL,
	"F" text NULL,
	"G" text NULL,
	"H" text NULL,
	"I" text NULL,
	"J" text NULL,
	"K" text NULL,
	"L" text NULL,
	"M" text NULL,
	"N" text NULL,
	"O" text NULL,
	"P" text NULL,
	"Q" text NULL,
	"R" text NULL,
	"S" text NULL,
	"T" text NULL,
	"U" text NULL,
	"V" text NULL,
	"W" text NULL,
	"X" text NULL,
	"Y" text NULL,
	"Z" text NULL,
	"Aa" text NULL,
	"Ab" text NULL,
	"Ac" text NULL,
	"Ad" text NULL,
	"Ae" text NULL,
	"Af" text NULL,
	"Ag" text NULL,
	"Ah" text NULL,
	"Ai" text NULL,
	"Aj" text NULL,
	"Ak" text NULL,
	"Al" text NULL,
	"Am" text NULL,
	"An" text NULL,
	"Ao" text NULL,
	"Ap" text NULL,
	"Aq" text NULL,
	"Ar" text NULL,
	"As" text NULL,
	"At" text NULL,
	"Au" text NULL,
	"Av" text NULL,
	"Aw" text NULL,
	"Ax" text NULL,
	"Ay" text NULL,
	"Az" text NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated"  timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT CustomerSpreadsheet_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_CustomerSpreadsheet_Customer FOREIGN KEY ("CustomerId") REFERENCES public."Customers"("Id")
);


create trigger tr_CustomerSpreadsheet_updated before update
  on public."CustomerSpreadsheets"
  for each row
  execute procedure public.fn_set_modified_fields();
 
 
-- public."ResourceRosters" definition

-- Drop table

-- DROP TABLE public."ResourceRosters";

CREATE TABLE public."ResourceRosters" (
	"Id" serial4 NOT NULL,
	"ResourceId" int4 NOT NULL,
	"Monday" bool NOT NULL,
	"Tuesday" bool NOT NULL,
	"Wednesday" bool NOT NULL,
	"Thursday" bool NOT NULL,
	"Friday" bool NOT NULL,
	"Saturday" bool NOT NULL,
	"Sunday" bool NOT NULL,
	"MondayStart" timestamptz NULL,
	"TuesdayStart" timestamptz NULL,
	"WednesdayStart" timestamptz NULL,
	"ThursdayStart" timestamptz NULL,
	"FridayStart" timestamptz NULL,
	"SaturdayStart" timestamptz NULL,
	"SundayStart" timestamptz NULL,
	"MondayEnd" timestamptz NULL,
	"TuesdayEnd" timestamptz NULL,
	"WednesdayEnd" timestamptz NULL,
	"ThursdayEnd" timestamptz NULL,
	"FridayEnd" timestamptz NULL,
	"SaturdayEnd" timestamptz NULL,
	"SundayEnd" timestamptz NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifiedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT ResourceRoster_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_ResourceRoster_Resource FOREIGN KEY ("ResourceId") REFERENCES public."Resources"("Id")  --PLAN TO ADD DESCRIPTION FIELD and put a resourceRosterID in the Resource Table...
);

create trigger tr_ResourceRoster_updated before update
  on public."ResourceRosters"
  for each row
  execute procedure public.fn_set_modified_fields();


-- public."WeeklyNotes" definition

-- Drop table

-- DROP TABLE public."WeeklyNotes";

CREATE TABLE public."WeeklyNotes" (
	"Id" serial4 NOT NULL,
	"LocaleId" int4 NOT NULL,
	"Note" text NULL,
	"WeekDay" smallint NOT NULL,
	CONSTRAINT WeeklyNote_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_WeeklyNote_Location FOREIGN KEY ("LocaleId") REFERENCES public."Locales"("Id")
);



-- public."Sales" definition

-- Drop table

-- DROP TABLE public."Sales";

CREATE TABLE public."Sales" (
	"Id" serial4 NOT NULL,
	"AppTimeId" int4 NOT NULL,
	"Cash" decimal(12,2) NULL,
	"Cheque" decimal(12,2) NULL,
	"Card" decimal(12,2) NULL,
	"Total" decimal(12,2) NULL,
	"CustPaid" bool NOT NULL default false,
	"TransactionDate" timestamptz NOT NULL,
	"UserId" int not null default public.fn_current_user_id() references public."Users"("Id"),
	"ModifedBy" int4 NULL,
	"DateCreated" timestamptz NOT NULL default now(),
	"DateModified" timestamptz NULL,
	CONSTRAINT Sale_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_Sale_AppTime FOREIGN KEY ("AppTimeId") REFERENCES public."AppTimes"("Id") on delete cascade
);
CREATE INDEX sales_sharedappid_idx ON public."Sales" USING btree ("AppTimeId");
CREATE INDEX sales_createddate_idx ON public."Sales" USING btree ("DateCreated");


create trigger tr_Sale_updated before update
  on public."Sales"
  for each row
  execute procedure public.fn_set_modified_fields();

 
-- public."AppCustomers" definition

-- Drop table

-- DROP TABLE public."AppCustomers";

CREATE TABLE public."AppCustomers" (
	"Id" serial4 NOT NULL,
	"AppTimeId" int4 NOT NULL,
	"CustomerId" int4 NOT NULL,
	CONSTRAINT AppCustomer_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_AppCustomer_AppTime FOREIGN KEY ("AppTimeId") REFERENCES public."AppTimes"("Id") on delete cascade,
	CONSTRAINT FK_AppCustomer_Customer FOREIGN KEY ("CustomerId") REFERENCES public."Customers"("Id")
);
CREATE INDEX appcustomer_customerid_idx ON public."AppCustomers" USING btree ("CustomerId");
CREATE INDEX appcustomer_sharedappid_idx ON public."AppCustomers" USING btree ("AppTimeId");


-- public.AppResource definition

-- Drop table

-- DROP TABLE public."AppResources";

CREATE TABLE public."AppResources" (
	"Id" serial4 NOT NULL,
	"AppTimeId" int4 NOT NULL,
	"ResourceId" int4 NOT NULL,
	CONSTRAINT AppResource_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_AppResource_AppTime FOREIGN KEY ("AppTimeId") REFERENCES public."AppTimes"("Id") on delete cascade,
	CONSTRAINT FK_AppResource_Resource FOREIGN KEY ("ResourceId") REFERENCES public."Resources"("Id")
);
CREATE INDEX appresource_ResourceId_idx ON public."AppResources" USING btree ("ResourceId");
CREATE INDEX appresource_sharedappid_idx ON public."AppResources" USING btree ("AppTimeId");


-- public."AppSales" definition

-- Drop table

-- DROP TABLE public."AppSales";

CREATE TABLE public."AppSales" (
	"Id" serial4 NOT NULL,
	"AppTimeId" int4 NOT NULL,
	"GoodServiceId" int4 NOT NULL,
	"ResourceId" int4 NOT NULL,
	"CustomerId" int4 NOT NULL,
	"Price" decimal(12,2) NOT NULL,
	"PriceSpecified" bool NOT NULL,
	CONSTRAINT AppSale_pkey PRIMARY KEY ("Id"),
	CONSTRAINT FK_AppSale_AppTime FOREIGN KEY ("AppTimeId") REFERENCES public."AppTimes"("Id") on delete cascade,
	CONSTRAINT FK_AppSale_Customer FOREIGN KEY ("CustomerId") REFERENCES public."Customers"("Id") on delete cascade,
	CONSTRAINT FK_AppSale_Resource FOREIGN KEY ("ResourceId") REFERENCES public."Resources"("Id") on delete cascade,
	CONSTRAINT FK_AppSale_GoodService FOREIGN KEY ("GoodServiceId") REFERENCES public."GoodServices"("Id") on delete cascade
);
CREATE INDEX appsale_sharedappid_idx ON public."AppSales" USING btree ("AppTimeId");





 
 
 

create extension if not exists "pgcrypto";


alter default privileges revoke execute on functions from public;

create or replace function public.fn_Register_User(
  "LocaleId" int4,
  "Permission" public.Permission,
  "FirstName" text,
  "LastName" text,
  "Email" text,  
  "Password" text,
  "IsClientAdmin" bool,
  "IsApproved" bool,
  "OpenIdUrl" text,
  "CreatedBy" int4
) returns public."Users" as $$
declare
  User public."Users";
begin
  insert into public."Users" ("LocaleId","Permission", "FirstName", "LastName", "OpenIdUrl", "IsClientAdmin", "IsApproved", "CreatedBy") values
    ("LocaleId", Permission, "FirstName", "LastName", OpenIdUrl, IsClientAdmin, IsApproved, CreatedBy)
    returning * into User;

  insert into private.Useraccount ("Id", "Email", "PasswordHash") values
    (public."Users".Id, email, crypt(Password, gen_salt('bf')));

  return User;
end;
$$ language plpgsql strict security definer;

comment on function public.fn_Register_User(int4, permission, text, text, text, text, bool, bool, text,int4) is 'Registers a single user and creates an account in the private schema.';




--A URL SAFE FIELD:
--slug text not null check(length(slug) < 30 and slug ~ '^([a-z0-9]-?)+$') unique,

--YOU CAN SPECIFY FIELDS AS WELL

--grant insert(slug, name, description) on app_public.forums to graphiledemo_visitor;
--grant update(slug, name, description) on app_public.forums to graphiledemo_visitor;
--grant delete on app_public.forums to graphiledemo_visitor;

--YOU CAN DEFUALT THE "CreatedBy" and ModifedBy fields!!

--""CreatedBy"" int not null default public.fn_current_user_id() references public.users on delete cascade,
  
  

--create policy select_all on public.forums for select using (true);
--create policy insert_admin on public.forums for insert with check (app_public.current_user_is_admin());
--create policy update_admin on public.forums for update using (app_public.current_user_is_admin());
--create policy delete_admin on public.forums for delete using (app_public.current_user_is_admin());



grant usage on schema private to perm_admin;

--MAKE THE private.Useraccount have RLS so only users can change their own records
alter table private."UserAccounts" enable row level security;

create policy update_user_account on private."UserAccounts" for update to perm_readwrite
  using ("Id" = current_setting('jwt.claims.id', true)::integer);

grant select on table private."UserAccounts" to perm_readonly, perm_readwrite, perm_admin;
grant update, delete on table private."UserAccounts" to perm_readonly, perm_readwrite, perm_admin;
--Don't need "grant usage on" as the fn_Register_User has security defined (security definer mean that this function is --executed with the privileges of the Postgres user who created it).


--Permission to view the PUBLIC schema
grant usage on schema public to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;

grant select on table public."Users" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Users" to perm_readonly, perm_readwrite, perm_admin;
grant usage on sequence public."Users_Id_seq" to perm_readonly, perm_readwrite, perm_admin;


grant select on table public."AppTimes" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert on table public."AppTimes" to perm_anon_customer, perm_readwrite, perm_admin;
grant update, delete on table public."AppTimes" to perm_readwrite, perm_admin;
grant usage on sequence public."AppTimes_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

grant select on table public."AppCustomers" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert on table public."AppCustomers" to perm_anon_customer, perm_readwrite, perm_admin;
grant update, delete on table public."AppCustomers" to perm_readwrite, perm_admin;
grant usage on sequence public."AppCustomers_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

--Anon Customers insert themselves - but only when we do a look up via Mobile phone number!!!
grant select on table public."Customers" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert on table public."Customers" to perm_anon_customer, perm_readwrite, perm_admin;
grant update, delete on table public."Customers" to perm_readwrite, perm_admin;
grant usage on sequence public."Customers_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

grant select on table public."AppResources" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert on table public."AppResources" to perm_anon_customer, perm_readwrite, perm_admin;
grant update, delete on table public."AppResources" to perm_readwrite, perm_admin;
grant usage on sequence public."AppResources_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

grant select on table public."AppSales" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."AppSales" to perm_anon_customer, perm_readwrite, perm_admin;
grant usage on sequence public."AppSales_Id_seq" to perm_anon_customer, perm_readwrite, perm_admin;

grant select on table public."Resources" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Resources" to perm_readwrite, perm_admin;
grant usage on sequence public."Resources_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."ResourceRosters" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."ResourceRosters" to perm_readwrite, perm_admin;
grant usage on sequence public."ResourceRosters_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."GoodServices" to perm_anon_customer, perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."GoodServices" to perm_readwrite, perm_admin;
grant usage on sequence public."GoodServices_Id_seq" to perm_readwrite, perm_admin;



grant select on table public."Cancellations" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Cancellations" to perm_readwrite, perm_admin;
grant usage on sequence public."Cancellations_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."CustomerSpreadsheets" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."CustomerSpreadsheets" to perm_readwrite, perm_admin;
grant usage on sequence public."CustomerSpreadsheets_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."Sales" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Sales" to perm_readwrite, perm_admin;
grant usage on sequence public."Sales_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."DailyNotes" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."DailyNotes" to perm_readwrite, perm_admin;
grant usage on sequence public."DailyNotes_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."WeeklyNotes" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."WeeklyNotes" to perm_readwrite, perm_admin;
grant usage on sequence public."WeeklyNotes_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."Tasks" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Tasks" to perm_readwrite, perm_admin;
grant usage on sequence public."Tasks_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."DescOrders" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."DescOrders" to perm_readwrite, perm_admin;
grant usage on sequence public."DescOrders_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."Letters" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Letters" to perm_readwrite, perm_admin;
grant usage on sequence public."Letters_Id_seq" to perm_readwrite, perm_admin;

grant select on table public."LetterHeads" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."LetterHeads" to perm_readwrite, perm_admin;
grant usage on sequence public."LetterHeads_Id_seq" to perm_readwrite, perm_admin;


-- View All, Edit Admin
grant select on table public."SMSBatchs" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."SMSBatchs" to perm_admin;
grant usage on sequence public."SMSBatchs_Id_seq" to perm_admin;

grant select on table public."SMSDeliverys" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."SMSDeliverys" to perm_admin;
grant usage on sequence public."SMSDeliverys_Id_seq" to perm_admin;

grant select on table public."SMSReplys" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."SMSReplys" to perm_admin;
grant usage on sequence public."SMSReplys_Id_seq" to perm_admin;


grant select on table public."Locales" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Locales" to perm_admin;
grant usage on sequence public."Locales_Id_seq" to perm_admin;

grant select on table public."Settings" to perm_readonly, perm_readwrite, perm_admin;
grant insert, update, delete on table public."Settings" to perm_admin;
grant usage on sequence public."Settings_Id_seq" to perm_admin;



--grant execute on function public.fn_Populate_GSNameTxtSearchToken() to perm_readwrite, perm_admin;
--grant execute on function public.fn_Populate_FullNameTxtSearchToken() to perm_readwrite, perm_admin;
grant execute on function public.fn_current_user_id() to perm_readwrite, perm_admin;
grant execute on function public.fn_set_modified_fields() to perm_readwrite, perm_admin;

grant execute on function public.fn_Register_User(int4, permission, text, text, text, text, bool, bool, text,int4) to  perm_readwrite, perm_admin;



 
 
 






ALTER SEQUENCE public."Settings_Id_seq" RESTART 1;


INSERT INTO public."Settings" ("SettingProperty","Description") VALUES
	 ('No working on Sunday''s','All Location Weekly Note'),
	 ('Monday Team Meeting','All Location Weekly Note'),
	 ('Tuesday Weekly Accounts','All Location Weekly Note'),
	 ('Potluck Lunch Wednesdays','All Location Weekly Note'),
	 ('Retrospective/Ceremony','All Location Weekly Note'),
	 ('Clean Premises','All Location Weekly Note'),
	 ('Review Roster','All Location Weekly Note'),
	 ('','Title'),
	 ('Ms','Title'),
	 ('Mr','Title'),
	 ('Mrs','Title'),
	 ('Dr','Title'),
	 ('Prof','Title'),
	 ('Dame','Title'),
	 ('Sir','Title'),
	 ('Lady','Title'),
	 ('Lord','Title');

/*
ALTER SEQUENCE public."Settings_Id_seq" RESTART 99;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES
	 ('','EMPTY');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES
	 ('Appointment','Type'),
	 ('Customer Sale','Type'),
	 ('Walk In Sale','Type');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 120;

INSERT INTO public."Settings" ("SettingProperty","Description") VALUES
('View ReadOnly Data','Permission'),
('Edit Data','Permission'),
('Edit Data & View Reports','Permission'),
('Global Admin','Permission');
*/


ALTER SEQUENCE public."Settings_Id_seq" RESTART 200;

INSERT INTO public."Settings" ("SettingProperty","Description") VALUES
	 ('0','Tally Appt Duration by GS Times'),
	 ('0','Default Payment Option (Cash, Cheque OR Credit)'),
	 ('1','Appointments By GS Color'),
	 ('5','Default Minutes for Appointment Reminders'),
	 ('1','Tooltips'),
	 ('1','Searches Default By Location'),
	 ('1','Users Require Admin Permission'),
	 ('0','Reports Require Admin Permission'),
	 ('1','Sales Editing Requires Admin Permission (Day after customer paid)'),
	 ('1','Marketing To All (NOT By Location) Requires Admin Permission'),
	 ('0','No Helpful MessagePrompts'),
	 ('0','Hide Invoice Label'),
	 ('1199','Default Industry Id'), -- ''
	 ('0','Default Customer Suburb/PostCode to Location'), -- Australia
	 ('1712','Default Customer Country Id'), -- Australia
	 ('0','Default Customer Title Id'),
	 ('','Default Customer Gender'), -- '','Other','Female','Male'
	 ('01/01/2000','Default Customer DateOfBirth'),
	 ('1500','Default Customer Industry'), -- Professionals
	 ('1','Mandatory Customer "FirstName"'),
	 ('1','Mandatory Customer "LastName"'),
	 ('1','Mandatory Customer Mobile'),	 
	 ('0','Mandatory Customer PostCode');

ALTER SEQUENCE public."Settings_Id_seq" RESTART 1199;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES 	 ('','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1200;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES 	 ('Accommodation and Food Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1220;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES ('Administrative and Support Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1240;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Agriculture, Forestry and Fishing','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1260;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Arts and Recreation Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1280;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Construction','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1300;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Education and Training','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1320;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Entertainment Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1350;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Executive','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1360;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Financial and Insurance Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1370;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Government and Defence','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1380;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Health Care and Social Assistance','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1390;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Hospitality, Travel and Tourism','Industry');

ALTER SEQUENCE public."Settings_Id_seq" RESTART 1400;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('IT and Telco','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1420;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES ('Manufacturing','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1440;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Media, Advertising and Arts','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1460;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Mining, Oil and Gas','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1480;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Personal Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1500;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Professional, Scientific and Tech. Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1520;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Public Administration and Safety','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1540;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Real Estate Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1560;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Retail Trade','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1570;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Retired','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1580;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Student/Graduate','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1590;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Trades and Services Reports','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1600;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES ('Transport, Postal and Warehousing','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1620;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Utility Elec., Gas, Water, Waste Services','Industry');
ALTER SEQUENCE public."Settings_Id_seq" RESTART 1640;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES('Wholesale Trade','Industry');


ALTER SEQUENCE public."Settings_Id_seq" RESTART 1700;
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Aaland' ,N'358');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Abkhazia' ,N'7');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Afghanistan' ,N'93');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Albania' ,N'355');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Algeria' ,N'2137');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'American Samoa' ,N'684');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Andorra' ,N'376');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Anguilla' ,N'1264');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Anla' ,N'244');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Antarctica' ,N'672');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Antigua' ,N'1268');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Argentina' ,N'54');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Armenia' ,N'3748');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Aruba' ,N'297');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ascension' ,N'247');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Australia' ,N'61');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Australia Northern Territory' ,N'672');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Austria' ,N'43');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Azerbaijan' ,N'9948');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bahamas' ,N'1242');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bahrain' ,N'973');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bangladesh' ,N'880');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Barbados' ,N'1246');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Barbuda' ,N'1268');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Belarus' ,N'3758');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Belgium' ,N'32');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Belize' ,N'501');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Benin' ,N'229');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bermuda' ,N'1441');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bhutan' ,N'975');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bolivia' ,N'591');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bosnia & Herzevina' ,N'387');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Botswana' ,N'267');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Brazil' ,N'55');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'British Virgin Islands' ,N'1284');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Brunei Darussalam' ,N'673');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Bulgaria' ,N'359');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Burkina Faso' ,N'226');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Burundi' ,N'257');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'CÃ´ted''Ivoire' ,N'225');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cambodia' ,N'855');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cameroon' ,N'237');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Canada' ,N'11');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'CapeVerde Islands' ,N'238');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cayman Islands' ,N'1345');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Central African Republic' ,N'236');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Chad' ,N'23515');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Chatham Island' ,N'64');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Chile' ,N'56');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'China' ,N'86');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Christmas Island' ,N'618');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cocos-Keeling Islands' ,N'61');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Colombia' ,N'57');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Comoros' ,N'269');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Congo' ,N'242');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cook Islands' ,N'682');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Costa Rica' ,N'506');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Croatia' ,N'385');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cuba' ,N'53119');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cuba (GuantanamoBay);' ,N'5399');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'CuraÃ§ao' ,N'599');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Cyprus' ,N'357');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Czech Republic' ,N'420');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Denmark' ,N'45');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Die Garcia' ,N'246');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Djibouti' ,N'253');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Dominica' ,N'1767');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Dominican Republic' ,N'1809');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'East Timor' ,N'670');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Easter Island' ,N'56');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ecuador' ,N'593');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Egypt' ,N'20');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'ElSalvador' ,N'503');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Equatorial Guinea' ,N'240');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Eritrea' ,N'291');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Estonia' ,N'372');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ethiopia' ,N'251');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Falkland Islands' ,N'500');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Faroe Islands' ,N'298');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Fiji Islands' ,N'679');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Finland' ,N'358');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'France' ,N'33');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'French Antilles' ,N'596');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'French Guiana' ,N'594');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'French Polynesia' ,N'689');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Gabonese Republic' ,N'241');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Gambia' ,N'220');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Georgia' ,N'9958');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Germany' ,N'49');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ghana' ,N'233');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Gibraltar' ,N'350');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Greece' ,N'30');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Greenland' ,N'299');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Grenada' ,N'1473');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guadeloupe' ,N'590');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guam' ,N'1671');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guatemala' ,N'502');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guernsey' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guinea' ,N'224');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guinea-Bissau' ,N'245');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Guyana' ,N'592');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Haiti' ,N'509');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Honduras' ,N'504');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Hong Kong' ,N'852');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Hungary' ,N'36');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Iceland' ,N'354');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'India' ,N'91');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Indonesia' ,N'62');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Iran' ,N'98');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Iraq' ,N'964');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ireland ' ,N'353');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Isle Of Man' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Israel' ,N'972');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Italy' ,N'39');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Jamaica' ,N'1876');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Japan' ,N'81');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Jersey' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Jordan' ,N'962');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kazakhstan' ,N'78');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kenya' ,N'254');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kenya' ,N'254');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kiribati' ,N'686');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Korea (North);' ,N'850');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Korea (South);' ,N'82');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kuwait' ,N'965');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Kyrgyzstan Republic' ,N'996');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Laos' ,N'856');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Latvia' ,N'3718');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Lebanon' ,N'961');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Lesotho' ,N'266');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Liberia' ,N'23122');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Libya' ,N'218');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Liechtenstein' ,N'423');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Lithuania' ,N'3708');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Luxembourg' ,N'352');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Macao' ,N'853');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Macedonia' ,N'389');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Madagascar' ,N'261');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Malawi' ,N'265');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Malaysia' ,N'60');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Maldives' ,N'960');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mali Republic' ,N'223');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Malta' ,N'356');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Marshall Islands' ,N'6921');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Martinique' ,N'596');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mauritania' ,N'222');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mauritius' ,N'230');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mayotte Island' ,N'269');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mexico' ,N'52');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Micronesia' ,N'6911');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Midway Island' ,N'1808');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Moldova' ,N'373');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Monaco' ,N'377');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Monlia' ,N'976');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Montenegro' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Montserrat' ,N'1664');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Morocco' ,N'212');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Mozambique' ,N'258');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Myanmar' ,N'95');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Namibia' ,N'264');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Narno Karabakh' ,N'382');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nauru' ,N'674');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nepal' ,N'977');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Netherlands' ,N'31');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Netherlands Antilles' ,N'599');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nevis' ,N'1869');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'New Caledonia' ,N'687');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'New Zealand' ,N'64');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nicaragua' ,N'505');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Niger' ,N'227');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Nigeria' ,N'234');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Niue' ,N'683');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Norfolk Island' ,N'672');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Northern Marianas Islands' ,N'1670');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Norway' ,N'47');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Oman' ,N'968');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Pakistan' ,N'92');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Palau' ,N'680');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Palestinian Settlements' ,N'970');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Panama' ,N'507');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Papua New Guinea' ,N'675');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Paraguay' ,N'595');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Peru' ,N'51');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Philippines' ,N'63');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Pitcairn' ,N'64');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Poland' ,N'48');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Portugal' ,N'351');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Puerto Rico' ,N'1787');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Qatar' ,N'974');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'RÃ©union Island' ,N'262');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Romania' ,N'40');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Russia' ,N'78');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Rwandese Republic' ,N'250');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'SÃ£o TomÃ© and Principe' ,N'239');

INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Samoa' ,N'685');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'San Marino' ,N'378');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Saudi Arabia' ,N'966');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Senegal' ,N'221');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Serbiaand Montenegro' ,N'38199');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Seychelles Republic' ,N'248');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sierra Leone' ,N'232');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Singapore' ,N'65');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Slovakia Republic' ,N'421');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Slovenia' ,N'386');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Solomon Islands' ,N'677');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Somali' ,N'252');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'South Africa' ,N'27');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Spain' ,N'34');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sri Lanka' ,N'94');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Helena' ,N'290');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Kitts/Nevis' ,N'1869');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Lucia' ,N'1758');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Pierre & Miquelon' ,N'508');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'St.Vincent & Grenadines' ,N'1784');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sudan' ,N'249');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Suriname' ,N'597');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Swaziland' ,N'268');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Sweden' ,N'46');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Switzerland' ,N'41');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Syria' ,N'963');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Taiwan' ,N'886');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tajikistan' ,N'9928');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tanzania' ,N'255');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Thailand' ,N'66');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Thuraya' ,N'88216');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tokelau' ,N'690');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tolese Republic' ,N'228');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tonga Islands' ,N'676');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Trinidad & Toba' ,N'1868');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tunisia' ,N'216');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Turkey' ,N'90');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Turkmenistan' ,N'9938');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Turks and Caicos Islands' ,N'1649');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Tuvalu' ,N'688');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Uganda' ,N'256');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Ukraine' ,N'3808');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'United Arab Emirates' ,N'971');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'United Kingdom' ,N'44');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Uruguay' ,N'598');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'US Virgin Islands' ,N'1340');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'USA' ,N'11');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Uzbekistan' ,N'9988');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Vanuatu' ,N'678');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Vatican City' ,N'39');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Venezuela' ,N'58');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Vietnam' ,N'84');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Wake Island' ,N'808');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Wallisand Futuna Islands' ,N'68119');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Western Samoa' ,N'685');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Western Sahara' ,N'212');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Yemen' ,N'967');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Zambia' ,N'260');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Zanzibar' ,N'255');
INSERT INTO public."Settings" ("SettingProperty","Description") VALUES (N'Zimbabwe' ,N'2630');










ALTER SEQUENCE public."DescOrders_Id_seq" RESTART 1;

INSERT INTO public."DescOrders" ("Order","Description","IsVisible") VALUES
	 (1,'Task',true),
	 (2,'Customers Name',true),
	 (3,'Resources Name',false),
	 (4,'Goods/Services',true),
	 (5,'Membership ID',false),
	 (5,'Customer Misc',false),
	 (6,'Start Time - FinishTime',true);


ALTER SEQUENCE public."LetterHeads_Id_seq" RESTART 1;

INSERT INTO public."LetterHeads" ("Text","Font","Size","Height","Alignment","Position","Bold","Italic","Underline") VALUES
	 ('PO Box 3052','Arial',9,20,0,1,false,false,false),
	 ('St Leonards','Arial',9,20,0,1,false,false,false),
	 ('Australia 2065','Arial',9,50,0,1,false,false,false),
	 ('AppointmentsBook.Net','Arial',12,200,2,2,true,false,true),
	 ('Simple Software','Arial',12,300,2,2,false,true,true),
	 ('TEL: +61 1234 5678','Arial',9,20,1,3,false,false,false),
	 ('info@AppointmentsBook.Net','Arial',9,20,1,3,false,false,false),
	 ('ABN: 40 123 456 789','Arial',9,50,1,3,false,false,false);


ALTER SEQUENCE public."Letters_Id_seq" RESTART 1;

INSERT INTO public."Letters" ("Title","Subject","Body","IsDeleted") VALUES
	 ('Appointment Confirmation','Appointment Confirmation','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-weight:bold;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Dear &lt;&lt;Title&gt;&gt; &lt;&lt;First Name&gt;&gt; &lt;&lt;Last Name&gt;&gt;|| </span></span></p><p></p><p style="font-family:MS Sans Serif;font-weight:bold;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>This a friendly reminder to confirm your appointment at &lt;&lt;TimeStart&gt;&gt; till &lt;&lt;TimeEnd&gt;&gt; on &lt;&lt;Appointment Date&gt;&gt;. </span></span></p><p></p><p style="font-family:MS Sans Serif;font-weight:bold;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Yours sincerely</span></span></p><p></p><p></p><p></p><p></p></div>',true),
	 ('Appointment Confirmation On LetterHead','Appointment Confirmation On LetterHead','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Dear &lt;&lt;Title&gt;&gt;  &lt;&lt;First Name&gt;&gt;  &lt;&lt;Last Name&gt;&gt; </span></span></p><p></p><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>This is a friendly reminder to confirm your appointment at &lt;&lt;TimeStart&gt;&gt; till &lt;&lt;TimeEnd&gt;&gt; on &lt;&lt;Appointment Date&gt;&gt;.</span></span></p><p></p><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Yours sincerely</span></span></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p><p></p></div>',true),
	 ('SMS Appointment Confirmation 1','SMS Appointment Confirmation 1','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Hi &lt;&lt;First Name&gt;&gt;, (your company name) confirming your appointment on &lt;&lt;Appointment Date&gt;&gt; at &lt;&lt;TimeStart&gt;&gt;. Reply with YES to Confirm, NO to Cancel or call (your phone number).</span></span></p><p></p></div>',false),
	 ('SMS Appointment Confirmation 2','SMS Appointment Confirmation 2','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Hi &lt;&lt;First Name&gt;&gt;, (your company name) confirming your &lt;&lt;Appointment Date&gt;&gt; appointment at &lt;&lt;TimeStart&gt;&gt;. Reply with YES to Confirm, NO to Cancel or call (your phone number).</span></span></p><p></p></div>',false),
	 ('Appointment confirmation','Appointment confirmation','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Dear &lt;&lt;Title&gt;&gt; &lt;&lt;First Name&gt;&gt; &lt;&lt;Last Name&gt;&gt;, </span></span></p><p></p><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>This a friendly reminder to confirm your appointment at &lt;&lt;TimeStart&gt;&gt; till &lt;&lt;TimeEnd&gt;&gt; on &lt;&lt;Appointment Date&gt;&gt;.</span></span></p><p></p><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Yours sincerely, </span></span></p><p></p><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>YOUR STORE.</span></span></p></div>',false),
	 ('SMS Advertisement','SMS Advertisement','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Hi &lt;&lt;First Name&gt;&gt;, COMPANY are offering 25% discounts on PRODUCT until end of MONTH. Keep this SMS to receive discount!</span></span></p></div>',false),
	 ('SMS Marketing / Promotion Message','SMS Marketing / Promotion Message','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Hi &lt;&lt;First Name&gt;&gt;, (your company name) is offering 30% off all Product for this week only! Keep this msg to redeem offer.</span></span></p></div>',false),
	 ('SMS Staff Meeting Reminder','SMS Staff Meeting Reminder','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Hi &lt;&lt;First Name&gt;&gt;, this is reminder that we have a staff meeting on &lt;&lt;Appointment Date&gt;&gt; at &lt;&lt;TimeStart&gt;&gt;. See you there!</span></span></p><p></p></div>',false),
	 ('Birthday Message And Offer','Birthday Message And Offer','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Hi &lt;&lt;First Name&gt;&gt;, Happy Bday from (your company name) . As a gift we are offering you 40% off all treatments this week. Keep this msg to redeem offer. Have a Great Day!</span></span></p></div>',false),
	 ('Birthday Message And Offer-','Birthday Message And Offer-','<div style="text-align:Left;font-family:Se;e UI;font-style:normal;font-weight:normal;font-size:12;color:#000000;"><p style="font-family:MS Sans Serif;font-size:11.333333333333332;margin:0 0 0 0;"><span><span>Hi &lt;&lt;First Name&gt;&gt;, (your company name) wishes you a Happy Bday. As a gift we would like to offer you 40% off all treatments for this week only.  Have a Great Day!</span></span></p></div>',false),
	 ('Appointment Confirmation On LetterHead','Appointment Confirmation On LetterHead','<p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';"><br /></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';">Dear &lt;&lt;Title&gt;&gt; &lt;&lt;First Name&gt;&gt; &lt;&lt;Last Name&gt;&gt;</p><p style="font-family:''Se;e UI'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';">This is a friendly reminder to confirm your appointment at &lt;&lt;TimeStart&gt;&gt; till &lt;&lt;TimeEnd&gt;&gt; on &lt;&lt;Appointment Date&gt;&gt;.</p><p style="font-family:''Se;e UI'';"></p><p style="margin-bottom:0px;font-family:''MS Sans Serif'';">Yours sincerely</p>',false);

	
	
ALTER SEQUENCE public."WeeklyNotes_Id_seq" RESTART 1;

INSERT INTO public."WeeklyNotes" ("Note","WeekDay","LocaleId") VALUES
	 ('Sunday',1,1),
	 ('Monday Mkrt''ing confirm appts',2,1),
	 ('Take out bins',3,1),
	 ('Call your mother',4,1),
	 ('Late night shopping',5,1),
	 ('Accounts Reconciliation',6,1),
	 ('Pick-up kids from sport',7,1);



--SELECT public.fn_Register_User(1,'Administrator','Admin','Admin','info@AppointmentsBook.com','PAssword', true, true, 'http://openid.net', 1);



ALTER SEQUENCE public."Resources_Id_seq" RESTART 1;
INSERT INTO public."Resources" ("OrderId","DisplayName","TitleSettingId","FirstName","LastName","Phone","Mobile","Email","VoipPhone","Address1","Address2","Suburb","State","PostCode","Sex","DateOfBirth","Active","LocaleId","Misc","Leave","ReturnFromLeave","DefaultGoodServicesCSV","PictureURLsCSV","AttachmentURLsCSV","MembershipId","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,'ResourceA',8,'Resource','A',NULL,'0412 234 567','info@AppointemtnsBook.Net',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,true,1,NULL,NULL,NULL,'false',NULL,NULL,NULL,1,NULL,'2022-01-01 00:00:00+11',NULL);


ALTER SEQUENCE public."ResourceRosters_Id_seq" RESTART 1;
INSERT INTO public."ResourceRosters" ("ResourceId","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday","MondayStart","TuesdayStart","WednesdayStart","ThursdayStart","FridayStart","SaturdayStart","SundayStart","MondayEnd","TuesdayEnd","WednesdayEnd","ThursdayEnd","FridayEnd","SaturdayEnd","SundayEnd","UserId","ModifiedBy","DateCreated","DateModified") VALUES
	 (1,true,true,true,true,true,false,false,'1900-01-01 09:00:00+10','1900-01-01 09:00:00+10','1900-01-01 09:00:00+10','1900-01-01 09:00:00+10','1900-01-01 09:00:00+10','1900-01-01 09:00:00+10','1900-01-01 09:00:00+10','1900-01-01 17:00:00+10','1900-01-01 17:00:00+10','1900-01-01 17:00:00+10','1900-01-01 17:00:00+10','1900-01-01 17:00:00+10','1900-01-01 17:00:00+10','1900-01-01 17:00:00+10',1,NULL,'2022-01-01 00:00:00+11',NULL);


	
ALTER SEQUENCE public."Tasks_Id_seq" RESTART 1;
INSERT INTO public."Tasks" ("Description","IsDeleted") VALUES
	 ('Getting Milk',false),
	 ('Gone to lunch',false),
	 ('In an internal meeting',false),
	 ('Out at a meeting',false),
	 ('On call',false),
	 ('On short break',false),
	 ('Gone to the Bank',false),
	 ('Away from my desk',false),
	 ('Emergency',false),
	 ('At the Dentist/Dr''s',false);

	
	

ALTER SEQUENCE public."Customers_Id_seq" RESTART 1;
	
INSERT INTO public."Customers" ("LocaleId", "FirstName", "LastName") VALUES 
(1, 'Jeremy', 'Thompson');

	
INSERT INTO public."Customers" ("LocaleId", "FirstName", "LastName") VALUES 
(1, 'John', 'Thomson');


INSERT INTO public."Customers" ("LocaleId", "FirstName", "LastName") VALUES 
(1, 'Jerry', 'Terry');


select * from public."Customers" where "FirstName" ilike '%Jer%';

	
ALTER SEQUENCE public."GoodServices_Id_seq" RESTART 1;
	
INSERT INTO public."GoodServices" ("Title") VALUES 
('Sample'),
('Men''s Hair Cut');

--
--INSERT INTO public."GoodServices" (Title) VALUES 
--('Women''s Shoulder Cut');
--
--
--select * from public."GoodServices" where "Title" ilike '%Cut%'
