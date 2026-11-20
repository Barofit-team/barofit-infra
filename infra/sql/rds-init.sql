-- RDS 최초 1회 초기화: 서비스별 계정 + 서비스별 스키마(소유자 = 해당 계정)
-- 마스터 계정(postgres)으로 barofit DB에 접속해 실행한다. 비밀번호는 파일에 넣지 않고 psql 변수로 주입한다.
--
--   psql -h <RDS_HOST> -U postgres -d barofit \
--     -v identity_pw="'...'" -v routine_pw="'...'" -v workout_pw="'...'" \
--     -v analytics_pw="'...'" -v report_pw="'...'" \
--     -f infra/sql/rds-init.sql
--
-- 이후 서비스가 기동하면 Flyway(ModuleMigrations)가 자기 스키마 안에 테이블을 만든다.
-- 스키마가 이미 존재하므로 createSchemas(true)는 CREATE SCHEMA를 실행하지 않는다.
-- 서비스 간 스키마 접근은 USAGE 권한이 없어 DB 레벨에서 차단된다.

CREATE ROLE identity_user  LOGIN PASSWORD :identity_pw;
CREATE ROLE routine_user   LOGIN PASSWORD :routine_pw;
CREATE ROLE workout_user   LOGIN PASSWORD :workout_pw;
CREATE ROLE analytics_user LOGIN PASSWORD :analytics_pw;
CREATE ROLE report_user    LOGIN PASSWORD :report_pw;

-- AWS RDS PostgreSQL 16+에서는 마스터(rds_superuser)가 새로 만든 Role을 소유자로
-- 스키마를 생성(AUTHORIZATION)하려면 해당 Role의 멤버여야 한다.
GRANT identity_user, routine_user, workout_user, analytics_user, report_user TO CURRENT_USER;

CREATE SCHEMA identity  AUTHORIZATION identity_user;
CREATE SCHEMA routine   AUTHORIZATION routine_user;
CREATE SCHEMA workout   AUTHORIZATION workout_user;
CREATE SCHEMA analytics AUTHORIZATION analytics_user;
CREATE SCHEMA report    AUTHORIZATION report_user;

-- public 스키마는 아무 서비스도 쓰지 않는다
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE barofit FROM PUBLIC;
GRANT CONNECT ON DATABASE barofit TO identity_user, routine_user, workout_user, analytics_user, report_user;

-- search_path를 자기 스키마로 고정
ALTER ROLE identity_user  SET search_path TO identity;
ALTER ROLE routine_user   SET search_path TO routine;
ALTER ROLE workout_user   SET search_path TO workout;
ALTER ROLE analytics_user SET search_path TO analytics;
ALTER ROLE report_user    SET search_path TO report;
