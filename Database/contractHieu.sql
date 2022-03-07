CREATE TABLE info (
    id integer,
    last_name character varying(100),
    first_name character varying(100),
    post_code bigint,
    first_code bigint NOT NULL,
    second_code bit(10),
    birth_date date,
    host_address inet,
    house json,
    bank_money money,
    point real,
    car_point smallint,
    house_point smallint NOT NULL,
    adrress text,
    search_text tsquery
);
INSERT INTO info ( id,last_name,first_name,post_code,first_code,second_code,birth_date,host_address,house,bank_money,point,car_point,house_point,adrress,search_text) VALUES (1,'hieu','tran',23,1,'0000000010','1996-01-01','127.0.0.1',null,2000,2.3,5,7,'456 Ma Tu','follow');
INSERT INTO info ( id,last_name,first_name,post_code,first_code,second_code,birth_date,host_address,house,bank_money,point,car_point,house_point,adrress,search_text) VALUES (1,'hoang','tran',23,1,'0000000010','1996-01-01','127.0.0.1',null,3000,5.6,7,8,'456 Ma Tu','hi');

