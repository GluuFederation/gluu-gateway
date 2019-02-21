--
-- PostgreSQL database dump
--

-- Dumped from database version 10.3 (Ubuntu 10.3-1.pgdg14.04+1)
-- Dumped by pg_dump version 10.3 (Ubuntu 10.3-1.pgdg14.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner:
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner:
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: konga_api_health_checks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_api_health_checks (
    id integer NOT NULL,
    api_id text,
    api json,
    health_check_endpoint text,
    notification_endpoint text,
    active boolean,
    data json,
    "createdAt" timestamp with time zone,
    "updatedAt" timestamp with time zone,
    "createdUserId" integer,
    "updatedUserId" integer
);


ALTER TABLE public.konga_api_health_checks OWNER TO postgres;

--
-- Name: konga_api_health_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_api_health_checks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.konga_api_health_checks_id_seq OWNER TO postgres;

--
-- Name: konga_api_health_checks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_api_health_checks_id_seq OWNED BY public.konga_api_health_checks.id;


--
-- Name: konga_clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_clients (
  id integer NOT NULL,
  oxd_id text,
  client_id text,
  client_secret text,
  context text,
  data json,
  "createdAt" timestamp with time zone,
  "updatedAt" timestamp with time zone,
  "createdUserId" integer,
  "updatedUserId" integer
);


ALTER TABLE public.konga_clients OWNER TO postgres;

--
-- Name: konga_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_clients_id_seq
  AS integer
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER TABLE public.konga_clients_id_seq OWNER TO postgres;

--
-- Name: konga_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_clients_id_seq OWNED BY public.konga_clients.id;


--
-- Name: konga_email_transports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_email_transports (
    id integer NOT NULL,
    name text,
    description text,
    schema json,
    settings json,
    active boolean,
    "createdAt" timestamp with time zone,
    "updatedAt" timestamp with time zone,
    "createdUserId" integer,
    "updatedUserId" integer
);


ALTER TABLE public.konga_email_transports OWNER TO postgres;

--
-- Name: konga_email_transports_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_email_transports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.konga_email_transports_id_seq OWNER TO postgres;

--
-- Name: konga_email_transports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_email_transports_id_seq OWNED BY public.konga_email_transports.id;


--
-- Name: konga_kong_nodes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_kong_nodes (
    id integer NOT NULL,
    name text,
    kong_admin_url text,
    kong_api_key text,
    kong_version text,
    health_checks boolean,
    health_check_details json,
    active boolean,
    "createdAt" timestamp with time zone,
    "updatedAt" timestamp with time zone,
    "createdUserId" integer,
    "updatedUserId" integer
);


ALTER TABLE public.konga_kong_nodes OWNER TO postgres;

--
-- Name: konga_kong_nodes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_kong_nodes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.konga_kong_nodes_id_seq OWNER TO postgres;

--
-- Name: konga_kong_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_kong_nodes_id_seq OWNED BY public.konga_kong_nodes.id;


--
-- Name: konga_kong_snapshot_schedules; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_kong_snapshot_schedules (
  id integer NOT NULL,
  connection integer,
  active boolean,
  cron text,
  "lastRunAt" date,
  "createdAt" timestamp with time zone,
  "updatedAt" timestamp with time zone,
  "createdUserId" integer,
  "updatedUserId" integer
);


ALTER TABLE public.konga_kong_snapshot_schedules OWNER TO postgres;

--
-- Name: konga_kong_snapshot_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.konga_kong_snapshot_schedules_id_seq
  AS integer
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER TABLE public.konga_kong_snapshot_schedules_id_seq OWNER TO postgres;

--
-- Name: konga_kong_snapshot_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_kong_snapshot_schedules_id_seq OWNED BY public.konga_kong_snapshot_schedules.id;


--
-- Name: konga_kong_snapshots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_kong_snapshots (
    id integer NOT NULL,
    name text,
    kong_node_name text,
    kong_node_url text,
    kong_version text,
    data json,
    "createdAt" timestamp with time zone,
    "updatedAt" timestamp with time zone,
    "createdUserId" integer,
    "updatedUserId" integer
);


ALTER TABLE public.konga_kong_snapshots OWNER TO postgres;

--
-- Name: konga_kong_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_kong_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.konga_kong_snapshots_id_seq OWNER TO postgres;

--
-- Name: konga_kong_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_kong_snapshots_id_seq OWNED BY public.konga_kong_snapshots.id;


--
-- Name: konga_passports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_passports (
    id integer NOT NULL,
    protocol text,
    password text,
    provider text,
    identifier text,
    tokens json,
    "user" integer,
    "createdAt" timestamp with time zone,
    "updatedAt" timestamp with time zone
);


ALTER TABLE public.konga_passports OWNER TO postgres;

--
-- Name: konga_passports_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_passports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.konga_passports_id_seq OWNER TO postgres;

--
-- Name: konga_passports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_passports_id_seq OWNED BY public.konga_passports.id;


--
-- Name: konga_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_settings (
    id integer NOT NULL,
    data json,
    "createdAt" timestamp with time zone,
    "updatedAt" timestamp with time zone,
    "createdUserId" integer,
    "updatedUserId" integer
);


ALTER TABLE public.konga_settings OWNER TO postgres;

--
-- Name: konga_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.konga_settings_id_seq OWNER TO postgres;

--
-- Name: konga_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_settings_id_seq OWNED BY public.konga_settings.id;


--
-- Name: konga_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE IF NOT EXISTS public.konga_users (
    id integer NOT NULL,
    username text,
    email text,
    "firstName" text,
    "lastName" text,
    admin boolean,
    node_id text,
    active boolean,
    "activationToken" text,
    node integer,
    "createdAt" timestamp with time zone,
    "updatedAt" timestamp with time zone,
    "createdUserId" integer,
    "updatedUserId" integer
);


ALTER TABLE public.konga_users OWNER TO postgres;

--
-- Name: konga_users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE IF NOT EXISTS public.konga_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.konga_users_id_seq OWNER TO postgres;

--
-- Name: konga_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.konga_users_id_seq OWNED BY public.konga_users.id;


--
-- Name: konga_api_health_checks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_api_health_checks ALTER COLUMN id SET DEFAULT nextval('public.konga_api_health_checks_id_seq'::regclass);


--
-- Name: konga_clients id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_clients ALTER COLUMN id SET DEFAULT nextval('public.konga_clients_id_seq'::regclass);


--
-- Name: konga_email_transports id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_email_transports ALTER COLUMN id SET DEFAULT nextval('public.konga_email_transports_id_seq'::regclass);


--
-- Name: konga_kong_nodes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_kong_nodes ALTER COLUMN id SET DEFAULT nextval('public.konga_kong_nodes_id_seq'::regclass);


--
-- Name: konga_kong_snapshot_schedules id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_kong_snapshot_schedules ALTER COLUMN id SET DEFAULT nextval('public.konga_kong_snapshot_schedules_id_seq'::regclass);


--
-- Name: konga_kong_snapshots id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_kong_snapshots ALTER COLUMN id SET DEFAULT nextval('public.konga_kong_snapshots_id_seq'::regclass);


--
-- Name: konga_passports id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_passports ALTER COLUMN id SET DEFAULT nextval('public.konga_passports_id_seq'::regclass);


--
-- Name: konga_settings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_settings ALTER COLUMN id SET DEFAULT nextval('public.konga_settings_id_seq'::regclass);


--
-- Name: konga_users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.konga_users ALTER COLUMN id SET DEFAULT nextval('public.konga_users_id_seq'::regclass);


--
-- Data for Name: konga_api_health_checks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_api_health_checks (id, api_id, api, health_check_endpoint, notification_endpoint, active, data, "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
\.


--
-- Data for Name: konga_clients; Type: TABLE DATA; Schema: public; Owner: postgres
--
COPY public.konga_clients (id, oxd_id, client_id, client_secret, context, data, "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
\.

--
-- Delete data if exist
--
DELETE FROM public.konga_email_transports;

--
-- Data for Name: konga_email_transports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_email_transports (id, name, description, schema, settings, active, "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
1	smtp	Send emails using the SMTP protocol	[{"name":"host","description":"The SMTP host","type":"text","required":true},{"name":"port","description":"The SMTP port","type":"text","required":true},{"name":"username","model":"auth.user","description":"The SMTP user username","type":"text","required":true},{"name":"password","model":"auth.pass","description":"The SMTP user password","type":"text","required":true}]	{"host":"","port":"","auth":{"user":"","pass":""}}	t	2018-04-24 15:51:08+05:30	2018-04-24 15:51:08+05:30	\N	\N
2	sendmail	Pipe messages to the sendmail command	\N	{"sendmail":true}	f	2018-04-24 15:51:08+05:30	2018-04-24 15:51:08+05:30	\N	\N
3	mailgun	Send emails through Mailgun’s Web API	[{"name":"api_key","model":"auth.api_key","description":"The API key that you got from www.mailgun.com/cp","type":"text","required":true},{"name":"domain","model":"auth.domain","description":"One of your domain names listed at your https://mailgun.com/app/domains","type":"text","required":true}]	{"auth":{"api_key":"","domain":""}}	f	2018-04-24 15:51:08+05:30	2018-04-24 15:51:08+05:30	\N	\N
\.


--
-- Delete data if exist
--
DELETE FROM public.konga_kong_nodes;


--
-- Data for Name: konga_kong_nodes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_kong_nodes (id, name, kong_admin_url, kong_api_key, kong_version, health_checks, health_check_details, active, "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
1	default	http://localhost:8001		0-14-x	f	\N	t	2018-04-24 15:51:08+05:30	2018-04-24 15:51:08+05:30	\N	\N
\.


--
-- Data for Name: konga_kong_snapshot_schedules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_kong_snapshot_schedules (id, connection, active, cron, "lastRunAt", "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
\.


--
-- Data for Name: konga_kong_snapshots; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_kong_snapshots (id, name, kong_node_name, kong_node_url, kong_version, data, "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
\.


--
-- Data for Name: konga_passports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_passports (id, protocol, password, provider, identifier, tokens, "user", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Delete data if exist
--
DELETE FROM public.konga_settings;

--
-- Data for Name: konga_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_settings (id, data, "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
1	{"signup_enable":true,"signup_require_activation":false,"is_only_admin_allow_login": false,"info_polling_interval":5000,"email_default_sender_name":"KONGA","email_default_sender":"konga@konga.test","email_notifications":false,"default_transport":"sendmail","notify_when":{"node_down":{"title":"A node is down or unresponsive","description":"Health checks must be enabled for the nodes that need to be monitored.","active":false},"api_down":{"title":"An API is down or unresponsive","description":"Health checks must be enabled for the APIs that need to be monitored.","active":false}},"integrations":[{"id":"slack","name":"Slack","image":"slack_rgb.png","config":{"enabled":false,"fields":[{"id":"slack_webhook_url","name":"Slack Webhook URL","type":"text","required":true,"value":""}],"slack_webhook_url":""}}],"user_permissions":{"apis":{"create":false,"read":true,"update":false,"delete":false},"consumers":{"create":false,"read":true,"update":false,"delete":false},"plugins":{"create":false,"read":true,"update":false,"delete":false},"webProxy":{"create":false,"read":true,"update":false,"delete":false},"upstreams":{"create":false,"read":true,"update":false,"delete":false},"certificates":{"create":false,"read":true,"update":false,"delete":false},"connections":{"create":false,"read":true,"update":false,"delete":false},"users":{"create":false,"read":true,"update":false,"delete":false}}}	2018-04-24 15:51:08+05:30	2018-04-24 15:51:08+05:30	\N	\N
\.


--
-- Data for Name: konga_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.konga_users (id, username, email, "firstName", "lastName", admin, node_id, active, "activationToken", node, "createdAt", "updatedAt", "createdUserId", "updatedUserId") FROM stdin;
\.


--
-- Name: konga_api_health_checks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_api_health_checks_id_seq', 1, false);


--
-- Name: konga_clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_clients_id_seq', 1, false);


--
-- Name: konga_email_transports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_email_transports_id_seq', 3, true);


--
-- Name: konga_kong_nodes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_kong_nodes_id_seq', 1, true);


--
-- Name: konga_kong_snapshot_schedules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_kong_snapshot_schedules_id_seq', 1, false);


--
-- Name: konga_kong_snapshots_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_kong_snapshots_id_seq', 1, false);


--
-- Name: konga_passports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_passports_id_seq', 1, false);


--
-- Name: konga_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_settings_id_seq', 1, true);


--
-- Name: konga_users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.konga_users_id_seq', 1, false);


--
-- Name: konga_api_health_checks konga_api_health_checks_api_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_api_health_checks_api_id_key')
THEN
ALTER TABLE ONLY public.konga_api_health_checks ADD CONSTRAINT konga_api_health_checks_api_id_key UNIQUE (api_id);
END IF;
END$$;

--
-- Name: konga_api_health_checks konga_api_health_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_api_health_checks_pkey')
THEN
ALTER TABLE ONLY public.konga_api_health_checks ADD CONSTRAINT konga_api_health_checks_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_clients konga_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_clients_pkey')
THEN
ALTER TABLE ONLY public.konga_clients ADD CONSTRAINT konga_clients_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_email_transports konga_email_transports_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_email_transports_name_key')
THEN
ALTER TABLE ONLY public.konga_email_transports ADD CONSTRAINT konga_email_transports_name_key UNIQUE (name);
END IF;
END$$;

--
-- Name: konga_email_transports konga_email_transports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_email_transports_pkey')
THEN
ALTER TABLE ONLY public.konga_email_transports ADD CONSTRAINT konga_email_transports_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_kong_nodes konga_kong_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_kong_nodes_pkey')
THEN
ALTER TABLE ONLY public.konga_kong_nodes ADD CONSTRAINT konga_kong_nodes_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_kong_snapshot_schedules konga_kong_snapshot_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_kong_snapshot_schedules_pkey')
THEN
ALTER TABLE ONLY public.konga_kong_snapshot_schedules ADD CONSTRAINT konga_kong_snapshot_schedules_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_kong_snapshots konga_kong_snapshots_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_kong_snapshots_name_key')
THEN
ALTER TABLE ONLY public.konga_kong_snapshots ADD CONSTRAINT konga_kong_snapshots_name_key UNIQUE (name);
END IF;
END$$;

--
-- Name: konga_kong_snapshots konga_kong_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_kong_snapshots_pkey')
THEN
ALTER TABLE ONLY public.konga_kong_snapshots ADD CONSTRAINT konga_kong_snapshots_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_passports konga_passports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_passports_pkey')
THEN
ALTER TABLE ONLY public.konga_passports ADD CONSTRAINT konga_passports_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_settings konga_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_settings_pkey')
THEN
ALTER TABLE ONLY public.konga_settings ADD CONSTRAINT konga_settings_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_users konga_users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_users_email_key')
THEN
ALTER TABLE ONLY public.konga_users ADD CONSTRAINT konga_users_email_key UNIQUE (email);
END IF;
END$$;

--
-- Name: konga_users konga_users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_users_pkey')
THEN
ALTER TABLE ONLY public.konga_users ADD CONSTRAINT konga_users_pkey PRIMARY KEY (id);
END IF;
END$$;

--
-- Name: konga_users konga_users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

DO $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname = 'konga_users_username_key')
THEN
ALTER TABLE ONLY public.konga_users ADD CONSTRAINT konga_users_username_key UNIQUE (username);
END IF;
END$$;

--
-- PostgreSQL database dump complete
--

