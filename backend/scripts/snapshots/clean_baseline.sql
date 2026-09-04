--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: satellite_user
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO satellite_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: object_detection_task_artifacts; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.object_detection_task_artifacts (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    type character varying(64) NOT NULL,
    label character varying(128),
    path text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.object_detection_task_artifacts OWNER TO satellite_user;

--
-- Name: object_detection_task_artifacts_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.object_detection_task_artifacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.object_detection_task_artifacts_id_seq OWNER TO satellite_user;

--
-- Name: object_detection_task_artifacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.object_detection_task_artifacts_id_seq OWNED BY public.object_detection_task_artifacts.id;


--
-- Name: object_detection_task_logs; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.object_detection_task_logs (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    stage_name character varying(128),
    level character varying(32) NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.object_detection_task_logs OWNER TO satellite_user;

--
-- Name: object_detection_task_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.object_detection_task_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.object_detection_task_logs_id_seq OWNER TO satellite_user;

--
-- Name: object_detection_task_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.object_detection_task_logs_id_seq OWNED BY public.object_detection_task_logs.id;


--
-- Name: object_detection_task_stages; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.object_detection_task_stages (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    name character varying(128) NOT NULL,
    title character varying(128),
    stage_order integer NOT NULL,
    status character varying(32) DEFAULT 'pending'::character varying NOT NULL,
    output_path text,
    details jsonb DEFAULT '{}'::jsonb,
    message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone
);


ALTER TABLE public.object_detection_task_stages OWNER TO satellite_user;

--
-- Name: object_detection_task_stages_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.object_detection_task_stages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.object_detection_task_stages_id_seq OWNER TO satellite_user;

--
-- Name: object_detection_task_stages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.object_detection_task_stages_id_seq OWNED BY public.object_detection_task_stages.id;


--
-- Name: object_detection_tasks; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.object_detection_tasks (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    status character varying(32) DEFAULT 'pending'::character varying NOT NULL,
    input_path text NOT NULL,
    classes character varying(255),
    draw_labels boolean DEFAULT false NOT NULL,
    current_stage character varying(64),
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone
);


ALTER TABLE public.object_detection_tasks OWNER TO satellite_user;

--
-- Name: COLUMN object_detection_tasks.status; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.object_detection_tasks.status IS 'pending/running/completed/failed';


--
-- Name: COLUMN object_detection_tasks.input_path; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.object_detection_tasks.input_path IS 'ENVI .dat 输入路径';


--
-- Name: COLUMN object_detection_tasks.classes; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.object_detection_tasks.classes IS '逗号分隔的类别 ID 或名称，空表示全部';


--
-- Name: object_detection_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.object_detection_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.object_detection_tasks_id_seq OWNER TO satellite_user;

--
-- Name: object_detection_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.object_detection_tasks_id_seq OWNED BY public.object_detection_tasks.id;


--
-- Name: remote_sensing_task_artifacts; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.remote_sensing_task_artifacts (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    type character varying(64) NOT NULL,
    label character varying(128),
    path text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.remote_sensing_task_artifacts OWNER TO satellite_user;

--
-- Name: COLUMN remote_sensing_task_artifacts.type; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_task_artifacts.type IS 'raw/preview 等';


--
-- Name: remote_sensing_task_artifacts_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.remote_sensing_task_artifacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.remote_sensing_task_artifacts_id_seq OWNER TO satellite_user;

--
-- Name: remote_sensing_task_artifacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.remote_sensing_task_artifacts_id_seq OWNED BY public.remote_sensing_task_artifacts.id;


--
-- Name: remote_sensing_task_logs; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.remote_sensing_task_logs (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    stage_name character varying(128),
    level character varying(32) NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.remote_sensing_task_logs OWNER TO satellite_user;

--
-- Name: remote_sensing_task_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.remote_sensing_task_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.remote_sensing_task_logs_id_seq OWNER TO satellite_user;

--
-- Name: remote_sensing_task_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.remote_sensing_task_logs_id_seq OWNED BY public.remote_sensing_task_logs.id;


--
-- Name: remote_sensing_task_stages; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.remote_sensing_task_stages (
    id bigint NOT NULL,
    task_id bigint NOT NULL,
    name character varying(128) NOT NULL,
    title character varying(128),
    stage_order integer NOT NULL,
    status character varying(32) DEFAULT 'pending'::character varying NOT NULL,
    output_path text,
    details jsonb DEFAULT '{}'::jsonb,
    message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone
);


ALTER TABLE public.remote_sensing_task_stages OWNER TO satellite_user;

--
-- Name: COLUMN remote_sensing_task_stages.details; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_task_stages.details IS 'JSON 结构的额外信息';


--
-- Name: remote_sensing_task_stages_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.remote_sensing_task_stages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.remote_sensing_task_stages_id_seq OWNER TO satellite_user;

--
-- Name: remote_sensing_task_stages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.remote_sensing_task_stages_id_seq OWNED BY public.remote_sensing_task_stages.id;


--
-- Name: remote_sensing_tasks; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.remote_sensing_tasks (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    status character varying(32) DEFAULT 'pending'::character varying NOT NULL,
    input_directory text NOT NULL,
    file_prefix character varying(255) NOT NULL,
    sensor character varying(64),
    current_stage character varying(64),
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    enable_detection boolean DEFAULT true NOT NULL,
    detection_classes character varying(255),
    detection_draw_labels boolean DEFAULT false NOT NULL,
    scenario_id bigint,
    satellite_id bigint,
    host_node_name character varying(255),
    executed_sat_id character varying(100)
);


ALTER TABLE public.remote_sensing_tasks OWNER TO satellite_user;

--
-- Name: COLUMN remote_sensing_tasks.name; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.name IS '任务名称，可用场景/景号';


--
-- Name: COLUMN remote_sensing_tasks.status; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.status IS 'pending/running/completed/failed';


--
-- Name: COLUMN remote_sensing_tasks.current_stage; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.current_stage IS '最新活跃阶段';


--
-- Name: COLUMN remote_sensing_tasks.enable_detection; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.enable_detection IS '是否在融合后执行 YOLOv8 目标识别';


--
-- Name: COLUMN remote_sensing_tasks.detection_classes; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.detection_classes IS '检测类别 ID/名称，逗号分隔，空表示全部';


--
-- Name: COLUMN remote_sensing_tasks.scenario_id; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.scenario_id IS '所属仿真场景（拓扑）';


--
-- Name: COLUMN remote_sensing_tasks.satellite_id; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.satellite_id IS '执行/关联卫星（satellites.id）';


--
-- Name: COLUMN remote_sensing_tasks.host_node_name; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.host_node_name IS '执行任务的 K8s 节点名';


--
-- Name: COLUMN remote_sensing_tasks.executed_sat_id; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.remote_sensing_tasks.executed_sat_id IS '实际执行节点 satellite.io/id（拓扑 sat_id）';


--
-- Name: remote_sensing_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.remote_sensing_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.remote_sensing_tasks_id_seq OWNER TO satellite_user;

--
-- Name: remote_sensing_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.remote_sensing_tasks_id_seq OWNED BY public.remote_sensing_tasks.id;


--
-- Name: router_links; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.router_links (
    id bigint NOT NULL,
    scenario_id bigint NOT NULL,
    src_router character varying(16) NOT NULL,
    dst_router character varying(16) NOT NULL,
    delay_ms double precision,
    loss double precision,
    bandwidth double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.router_links OWNER TO satellite_user;

--
-- Name: router_links_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.router_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.router_links_id_seq OWNER TO satellite_user;

--
-- Name: router_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.router_links_id_seq OWNED BY public.router_links.id;


--
-- Name: router_nodes; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.router_nodes (
    id bigint NOT NULL,
    scenario_id bigint NOT NULL,
    router_id character varying(16) NOT NULL,
    sat_id character varying(100) NOT NULL,
    plane_index integer NOT NULL,
    sat_index_in_plane integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.router_nodes OWNER TO satellite_user;

--
-- Name: router_nodes_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.router_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.router_nodes_id_seq OWNER TO satellite_user;

--
-- Name: router_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.router_nodes_id_seq OWNED BY public.router_nodes.id;


--
-- Name: satellite_delay_edges; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.satellite_delay_edges (
    id bigint NOT NULL,
    scenario_id bigint NOT NULL,
    a_id character varying(100) NOT NULL,
    b_id character varying(100) NOT NULL,
    delay_s double precision NOT NULL,
    dist_km double precision NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.satellite_delay_edges OWNER TO satellite_user;

--
-- Name: satellite_delay_edges_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.satellite_delay_edges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.satellite_delay_edges_id_seq OWNER TO satellite_user;

--
-- Name: satellite_delay_edges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.satellite_delay_edges_id_seq OWNED BY public.satellite_delay_edges.id;


--
-- Name: satellite_states; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.satellite_states (
    id bigint NOT NULL,
    scenario_id bigint NOT NULL,
    sat_id character varying(100) NOT NULL,
    t_utc timestamp with time zone NOT NULL,
    r_x double precision NOT NULL,
    r_y double precision NOT NULL,
    r_z double precision NOT NULL,
    lla_lat double precision,
    lla_lon double precision,
    lla_alt double precision,
    coe_sma_km double precision,
    coe_ecc double precision,
    coe_inc_deg double precision,
    coe_raan_deg double precision,
    coe_argp_deg double precision,
    coe_ta_deg double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.satellite_states OWNER TO satellite_user;

--
-- Name: satellite_states_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.satellite_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.satellite_states_id_seq OWNER TO satellite_user;

--
-- Name: satellite_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.satellite_states_id_seq OWNED BY public.satellite_states.id;


--
-- Name: satellites; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.satellites (
    id bigint NOT NULL,
    scenario_id bigint NOT NULL,
    sat_id character varying(100) NOT NULL,
    stk_name character varying(255) NOT NULL,
    plane_index integer NOT NULL,
    sat_index_in_plane integer NOT NULL,
    alt_km double precision NOT NULL,
    sma_km double precision NOT NULL,
    ecc double precision NOT NULL,
    inc_deg double precision NOT NULL,
    raan_deg double precision NOT NULL,
    argp_deg double precision NOT NULL,
    ta_deg double precision NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.satellites OWNER TO satellite_user;

--
-- Name: TABLE satellites; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON TABLE public.satellites IS '卫星';


--
-- Name: COLUMN satellites.sat_id; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.sat_id IS '卫星ID';


--
-- Name: COLUMN satellites.stk_name; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.stk_name IS 'STK名称';


--
-- Name: COLUMN satellites.plane_index; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.plane_index IS '轨道面索引';


--
-- Name: COLUMN satellites.sat_index_in_plane; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.sat_index_in_plane IS '轨道面内卫星索引';


--
-- Name: COLUMN satellites.alt_km; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.alt_km IS '高度(km)';


--
-- Name: COLUMN satellites.sma_km; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.sma_km IS '半长轴(km)';


--
-- Name: COLUMN satellites.ecc; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.ecc IS '偏心率';


--
-- Name: COLUMN satellites.inc_deg; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.inc_deg IS '倾角(度)';


--
-- Name: COLUMN satellites.raan_deg; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.raan_deg IS '升交点赤经(度)';


--
-- Name: COLUMN satellites.argp_deg; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.argp_deg IS '近地点幅角(度)';


--
-- Name: COLUMN satellites.ta_deg; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.satellites.ta_deg IS '真近点角(度)';


--
-- Name: satellites_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.satellites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.satellites_id_seq OWNER TO satellite_user;

--
-- Name: satellites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.satellites_id_seq OWNED BY public.satellites.id;


--
-- Name: scenarios; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.scenarios (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    epoch character varying(100) NOT NULL,
    start_time character varying(100) NOT NULL,
    end_time character varying(100) NOT NULL,
    alt_km double precision NOT NULL,
    inc_deg double precision NOT NULL,
    n_planes integer NOT NULL,
    n_sats_per_plane integer NOT NULL,
    sensor_config jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


ALTER TABLE public.scenarios OWNER TO satellite_user;

--
-- Name: TABLE scenarios; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON TABLE public.scenarios IS '场景';


--
-- Name: COLUMN scenarios.name; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.name IS '场景名称';


--
-- Name: COLUMN scenarios.epoch; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.epoch IS '历元时间';


--
-- Name: COLUMN scenarios.start_time; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.start_time IS '开始时间';


--
-- Name: COLUMN scenarios.end_time; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.end_time IS '结束时间';


--
-- Name: COLUMN scenarios.alt_km; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.alt_km IS '高度(km)';


--
-- Name: COLUMN scenarios.inc_deg; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.inc_deg IS '倾角(度)';


--
-- Name: COLUMN scenarios.n_planes; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.n_planes IS '轨道面数量';


--
-- Name: COLUMN scenarios.n_sats_per_plane; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.n_sats_per_plane IS '每轨道面卫星数';


--
-- Name: COLUMN scenarios.sensor_config; Type: COMMENT; Schema: public; Owner: satellite_user
--

COMMENT ON COLUMN public.scenarios.sensor_config IS '传感器配置';


--
-- Name: scenarios_id_seq; Type: SEQUENCE; Schema: public; Owner: satellite_user
--

CREATE SEQUENCE public.scenarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.scenarios_id_seq OWNER TO satellite_user;

--
-- Name: scenarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: satellite_user
--

ALTER SEQUENCE public.scenarios_id_seq OWNED BY public.scenarios.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: satellite_user
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    dirty boolean NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO satellite_user;

--
-- Name: object_detection_task_artifacts id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_artifacts ALTER COLUMN id SET DEFAULT nextval('public.object_detection_task_artifacts_id_seq'::regclass);


--
-- Name: object_detection_task_logs id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_logs ALTER COLUMN id SET DEFAULT nextval('public.object_detection_task_logs_id_seq'::regclass);


--
-- Name: object_detection_task_stages id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_stages ALTER COLUMN id SET DEFAULT nextval('public.object_detection_task_stages_id_seq'::regclass);


--
-- Name: object_detection_tasks id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_tasks ALTER COLUMN id SET DEFAULT nextval('public.object_detection_tasks_id_seq'::regclass);


--
-- Name: remote_sensing_task_artifacts id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_artifacts ALTER COLUMN id SET DEFAULT nextval('public.remote_sensing_task_artifacts_id_seq'::regclass);


--
-- Name: remote_sensing_task_logs id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_logs ALTER COLUMN id SET DEFAULT nextval('public.remote_sensing_task_logs_id_seq'::regclass);


--
-- Name: remote_sensing_task_stages id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_stages ALTER COLUMN id SET DEFAULT nextval('public.remote_sensing_task_stages_id_seq'::regclass);


--
-- Name: remote_sensing_tasks id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_tasks ALTER COLUMN id SET DEFAULT nextval('public.remote_sensing_tasks_id_seq'::regclass);


--
-- Name: router_links id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.router_links ALTER COLUMN id SET DEFAULT nextval('public.router_links_id_seq'::regclass);


--
-- Name: router_nodes id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.router_nodes ALTER COLUMN id SET DEFAULT nextval('public.router_nodes_id_seq'::regclass);


--
-- Name: satellite_delay_edges id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellite_delay_edges ALTER COLUMN id SET DEFAULT nextval('public.satellite_delay_edges_id_seq'::regclass);


--
-- Name: satellite_states id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellite_states ALTER COLUMN id SET DEFAULT nextval('public.satellite_states_id_seq'::regclass);


--
-- Name: satellites id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellites ALTER COLUMN id SET DEFAULT nextval('public.satellites_id_seq'::regclass);


--
-- Name: scenarios id; Type: DEFAULT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.scenarios ALTER COLUMN id SET DEFAULT nextval('public.scenarios_id_seq'::regclass);


--
-- Data for Name: object_detection_task_artifacts; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.object_detection_task_artifacts (id, task_id, type, label, path, metadata, created_at) FROM stdin;
\.


--
-- Data for Name: object_detection_task_logs; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.object_detection_task_logs (id, task_id, stage_name, level, content, created_at) FROM stdin;
\.


--
-- Data for Name: object_detection_task_stages; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.object_detection_task_stages (id, task_id, name, title, stage_order, status, output_path, details, message, created_at, updated_at, started_at, finished_at) FROM stdin;
\.


--
-- Data for Name: object_detection_tasks; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.object_detection_tasks (id, name, status, input_path, classes, draw_labels, current_stage, error_message, created_at, updated_at, started_at, finished_at) FROM stdin;
\.


--
-- Data for Name: remote_sensing_task_artifacts; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.remote_sensing_task_artifacts (id, task_id, type, label, path, metadata, created_at) FROM stdin;
\.


--
-- Data for Name: remote_sensing_task_logs; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.remote_sensing_task_logs (id, task_id, stage_name, level, content, created_at) FROM stdin;
\.


--
-- Data for Name: remote_sensing_task_stages; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.remote_sensing_task_stages (id, task_id, name, title, stage_order, status, output_path, details, message, created_at, updated_at, started_at, finished_at) FROM stdin;
\.


--
-- Data for Name: remote_sensing_tasks; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.remote_sensing_tasks (id, name, status, input_directory, file_prefix, sensor, current_stage, error_message, created_at, updated_at, started_at, finished_at, enable_detection, detection_classes, detection_draw_labels, scenario_id, satellite_id, host_node_name, executed_sat_id) FROM stdin;
\.


--
-- Data for Name: router_links; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.router_links (id, scenario_id, src_router, dst_router, delay_ms, loss, bandwidth, created_at, updated_at) FROM stdin;
1	2	r001001	r001002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
2	2	r001001	r001002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
3	2	r001001	r002001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
4	2	r001002	r001001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
5	2	r001002	r001001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
6	2	r001002	r002002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
7	2	r001002	r001003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
8	2	r001003	r001002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
9	2	r001003	r001002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
10	2	r001003	r002003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
11	2	r001003	r001004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
12	2	r001004	r001003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
13	2	r001004	r001003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
14	2	r001004	r001005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
15	2	r001004	r002004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
16	2	r001005	r001004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
17	2	r001005	r001004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
18	2	r001005	r002005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
19	2	r002001	r001001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
20	2	r002001	r001001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
21	2	r002001	r002002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
22	2	r002001	r003001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
23	2	r002002	r001002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
24	2	r002002	r002001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
25	2	r002002	r001002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
26	2	r002002	r002003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
27	2	r002002	r003002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
28	2	r002003	r001003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
29	2	r002003	r002002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
30	2	r002003	r001003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
31	2	r002003	r003003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
32	2	r002003	r002004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
33	2	r002004	r001004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
34	2	r002004	r002003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
35	2	r002004	r002005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
36	2	r002004	r001004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
37	2	r002004	r003004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
38	2	r002005	r001005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
39	2	r002005	r002004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
40	2	r002005	r001005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
41	2	r002005	r003005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
42	2	r003001	r002001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
43	2	r003001	r002001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
44	2	r003001	r003002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
45	2	r003002	r002002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
46	2	r003002	r003001	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
47	2	r003002	r002002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
48	2	r003002	r003003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
49	2	r003003	r002003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
50	2	r003003	r003002	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
51	2	r003003	r002003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
52	2	r003003	r003004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
53	2	r003004	r002004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
54	2	r003004	r003003	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
55	2	r003004	r002004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
56	2	r003004	r003005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
57	2	r003005	r002005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
58	2	r003005	r003004	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
59	2	r003005	r002005	\N	\N	\N	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
\.


--
-- Data for Name: router_nodes; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.router_nodes (id, scenario_id, router_id, sat_id, plane_index, sat_index_in_plane, created_at, updated_at) FROM stdin;
1	2	r001004	sat-1-4	1	4	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
2	2	r002002	sat-2-2	2	2	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
3	2	r002003	sat-2-3	2	3	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
4	2	r003001	sat-3-1	3	1	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
5	2	r002004	sat-2-4	2	4	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
6	2	r002005	sat-2-5	2	5	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
7	2	r003004	sat-3-4	3	4	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
8	2	r001001	sat-1-1	1	1	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
9	2	r001002	sat-1-2	1	2	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
10	2	r001003	sat-1-3	1	3	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
11	2	r003003	sat-3-3	3	3	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
12	2	r001005	sat-1-5	1	5	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
13	2	r002001	sat-2-1	2	1	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
14	2	r003002	sat-3-2	3	2	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
15	2	r003005	sat-3-5	3	5	2026-08-21 11:53:23.509902+08	2026-08-21 11:53:23.509902+08
\.


--
-- Data for Name: satellite_delay_edges; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.satellite_delay_edges (id, scenario_id, a_id, b_id, delay_s, dist_km, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: satellite_states; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.satellite_states (id, scenario_id, sat_id, t_utc, r_x, r_y, r_z, lla_lat, lla_lon, lla_alt, coe_sma_km, coe_ecc, coe_inc_deg, coe_raan_deg, coe_argp_deg, coe_ta_deg, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: satellites; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.satellites (id, scenario_id, sat_id, stk_name, plane_index, sat_index_in_plane, alt_km, sma_km, ecc, inc_deg, raan_deg, argp_deg, ta_deg, created_at, updated_at, deleted_at) FROM stdin;
1	1	sat-1-1	Sat_1_1	1	1	550	6928.137	0	53	0	0	0	2026-08-21 11:53:22.746103+08	2026-08-21 11:53:22.746103+08	\N
2	1	sat-1-2	Sat_1_2	1	2	550	6928.137	0	53	0	0	16.363636363636363	2026-08-21 11:53:22.746103+08	2026-08-21 11:53:22.746103+08	\N
3	1	sat-1-3	Sat_1_3	1	3	550	6928.137	0	53	0	0	32.72727272727273	2026-08-21 11:53:22.746103+08	2026-08-21 11:53:22.746103+08	\N
4	2	sat-1-1	Sat_1_1	1	1	550	6928.137	0	53	0	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
5	2	sat-1-2	Sat_1_2	1	2	550	6928.137	0	53	0	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
6	2	sat-1-3	Sat_1_3	1	3	550	6928.137	0	53	0	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
7	2	sat-1-4	Sat_1_4	1	4	550	6928.137	0	53	0	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
8	2	sat-1-5	Sat_1_5	1	5	550	6928.137	0	53	0	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
9	2	sat-1-6	Sat_1_6	1	6	550	6928.137	0	53	0	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
10	2	sat-1-7	Sat_1_7	1	7	550	6928.137	0	53	0	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
11	2	sat-1-8	Sat_1_8	1	8	550	6928.137	0	53	0	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
12	2	sat-1-9	Sat_1_9	1	9	550	6928.137	0	53	0	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
13	2	sat-1-10	Sat_1_10	1	10	550	6928.137	0	53	0	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
14	2	sat-1-11	Sat_1_11	1	11	550	6928.137	0	53	0	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
15	2	sat-1-12	Sat_1_12	1	12	550	6928.137	0	53	0	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
16	2	sat-1-13	Sat_1_13	1	13	550	6928.137	0	53	0	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
17	2	sat-1-14	Sat_1_14	1	14	550	6928.137	0	53	0	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
18	2	sat-1-15	Sat_1_15	1	15	550	6928.137	0	53	0	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
19	2	sat-1-16	Sat_1_16	1	16	550	6928.137	0	53	0	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
20	2	sat-1-17	Sat_1_17	1	17	550	6928.137	0	53	0	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
21	2	sat-1-18	Sat_1_18	1	18	550	6928.137	0	53	0	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
22	2	sat-1-19	Sat_1_19	1	19	550	6928.137	0	53	0	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
23	2	sat-1-20	Sat_1_20	1	20	550	6928.137	0	53	0	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
24	2	sat-1-21	Sat_1_21	1	21	550	6928.137	0	53	0	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
25	2	sat-1-22	Sat_1_22	1	22	550	6928.137	0	53	0	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
26	2	sat-2-1	Sat_2_1	2	1	550	6928.137	0	53	10	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
27	2	sat-2-2	Sat_2_2	2	2	550	6928.137	0	53	10	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
28	2	sat-2-3	Sat_2_3	2	3	550	6928.137	0	53	10	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
29	2	sat-2-4	Sat_2_4	2	4	550	6928.137	0	53	10	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
30	2	sat-2-5	Sat_2_5	2	5	550	6928.137	0	53	10	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
31	2	sat-2-6	Sat_2_6	2	6	550	6928.137	0	53	10	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
32	2	sat-2-7	Sat_2_7	2	7	550	6928.137	0	53	10	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
33	2	sat-2-8	Sat_2_8	2	8	550	6928.137	0	53	10	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
34	2	sat-2-9	Sat_2_9	2	9	550	6928.137	0	53	10	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
35	2	sat-2-10	Sat_2_10	2	10	550	6928.137	0	53	10	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
36	2	sat-2-11	Sat_2_11	2	11	550	6928.137	0	53	10	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
37	2	sat-2-12	Sat_2_12	2	12	550	6928.137	0	53	10	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
38	2	sat-2-13	Sat_2_13	2	13	550	6928.137	0	53	10	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
39	2	sat-2-14	Sat_2_14	2	14	550	6928.137	0	53	10	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
40	2	sat-2-15	Sat_2_15	2	15	550	6928.137	0	53	10	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
41	2	sat-2-16	Sat_2_16	2	16	550	6928.137	0	53	10	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
42	2	sat-2-17	Sat_2_17	2	17	550	6928.137	0	53	10	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
43	2	sat-2-18	Sat_2_18	2	18	550	6928.137	0	53	10	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
44	2	sat-2-19	Sat_2_19	2	19	550	6928.137	0	53	10	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
45	2	sat-2-20	Sat_2_20	2	20	550	6928.137	0	53	10	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
46	2	sat-2-21	Sat_2_21	2	21	550	6928.137	0	53	10	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
47	2	sat-2-22	Sat_2_22	2	22	550	6928.137	0	53	10	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
48	2	sat-3-1	Sat_3_1	3	1	550	6928.137	0	53	20	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
49	2	sat-3-2	Sat_3_2	3	2	550	6928.137	0	53	20	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
50	2	sat-3-3	Sat_3_3	3	3	550	6928.137	0	53	20	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
51	2	sat-3-4	Sat_3_4	3	4	550	6928.137	0	53	20	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
52	2	sat-3-5	Sat_3_5	3	5	550	6928.137	0	53	20	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
53	2	sat-3-6	Sat_3_6	3	6	550	6928.137	0	53	20	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
54	2	sat-3-7	Sat_3_7	3	7	550	6928.137	0	53	20	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
55	2	sat-3-8	Sat_3_8	3	8	550	6928.137	0	53	20	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
56	2	sat-3-9	Sat_3_9	3	9	550	6928.137	0	53	20	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
57	2	sat-3-10	Sat_3_10	3	10	550	6928.137	0	53	20	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
58	2	sat-3-11	Sat_3_11	3	11	550	6928.137	0	53	20	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
59	2	sat-3-12	Sat_3_12	3	12	550	6928.137	0	53	20	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
60	2	sat-3-13	Sat_3_13	3	13	550	6928.137	0	53	20	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
61	2	sat-3-14	Sat_3_14	3	14	550	6928.137	0	53	20	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
62	2	sat-3-15	Sat_3_15	3	15	550	6928.137	0	53	20	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
63	2	sat-3-16	Sat_3_16	3	16	550	6928.137	0	53	20	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
64	2	sat-3-17	Sat_3_17	3	17	550	6928.137	0	53	20	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
65	2	sat-3-18	Sat_3_18	3	18	550	6928.137	0	53	20	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
66	2	sat-3-19	Sat_3_19	3	19	550	6928.137	0	53	20	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
67	2	sat-3-20	Sat_3_20	3	20	550	6928.137	0	53	20	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
68	2	sat-3-21	Sat_3_21	3	21	550	6928.137	0	53	20	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
69	2	sat-3-22	Sat_3_22	3	22	550	6928.137	0	53	20	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
70	2	sat-4-1	Sat_4_1	4	1	550	6928.137	0	53	30	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
71	2	sat-4-2	Sat_4_2	4	2	550	6928.137	0	53	30	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
72	2	sat-4-3	Sat_4_3	4	3	550	6928.137	0	53	30	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
73	2	sat-4-4	Sat_4_4	4	4	550	6928.137	0	53	30	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
74	2	sat-4-5	Sat_4_5	4	5	550	6928.137	0	53	30	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
75	2	sat-4-6	Sat_4_6	4	6	550	6928.137	0	53	30	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
76	2	sat-4-7	Sat_4_7	4	7	550	6928.137	0	53	30	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
77	2	sat-4-8	Sat_4_8	4	8	550	6928.137	0	53	30	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
78	2	sat-4-9	Sat_4_9	4	9	550	6928.137	0	53	30	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
79	2	sat-4-10	Sat_4_10	4	10	550	6928.137	0	53	30	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
80	2	sat-4-11	Sat_4_11	4	11	550	6928.137	0	53	30	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
81	2	sat-4-12	Sat_4_12	4	12	550	6928.137	0	53	30	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
82	2	sat-4-13	Sat_4_13	4	13	550	6928.137	0	53	30	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
83	2	sat-4-14	Sat_4_14	4	14	550	6928.137	0	53	30	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
84	2	sat-4-15	Sat_4_15	4	15	550	6928.137	0	53	30	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
85	2	sat-4-16	Sat_4_16	4	16	550	6928.137	0	53	30	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
86	2	sat-4-17	Sat_4_17	4	17	550	6928.137	0	53	30	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
87	2	sat-4-18	Sat_4_18	4	18	550	6928.137	0	53	30	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
88	2	sat-4-19	Sat_4_19	4	19	550	6928.137	0	53	30	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
89	2	sat-4-20	Sat_4_20	4	20	550	6928.137	0	53	30	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
90	2	sat-4-21	Sat_4_21	4	21	550	6928.137	0	53	30	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
91	2	sat-4-22	Sat_4_22	4	22	550	6928.137	0	53	30	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
92	2	sat-5-1	Sat_5_1	5	1	550	6928.137	0	53	40	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
93	2	sat-5-2	Sat_5_2	5	2	550	6928.137	0	53	40	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
94	2	sat-5-3	Sat_5_3	5	3	550	6928.137	0	53	40	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
95	2	sat-5-4	Sat_5_4	5	4	550	6928.137	0	53	40	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
96	2	sat-5-5	Sat_5_5	5	5	550	6928.137	0	53	40	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
97	2	sat-5-6	Sat_5_6	5	6	550	6928.137	0	53	40	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
98	2	sat-5-7	Sat_5_7	5	7	550	6928.137	0	53	40	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
99	2	sat-5-8	Sat_5_8	5	8	550	6928.137	0	53	40	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
100	2	sat-5-9	Sat_5_9	5	9	550	6928.137	0	53	40	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
101	2	sat-5-10	Sat_5_10	5	10	550	6928.137	0	53	40	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
102	2	sat-5-11	Sat_5_11	5	11	550	6928.137	0	53	40	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
103	2	sat-5-12	Sat_5_12	5	12	550	6928.137	0	53	40	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
104	2	sat-5-13	Sat_5_13	5	13	550	6928.137	0	53	40	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
105	2	sat-5-14	Sat_5_14	5	14	550	6928.137	0	53	40	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
106	2	sat-5-15	Sat_5_15	5	15	550	6928.137	0	53	40	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
107	2	sat-5-16	Sat_5_16	5	16	550	6928.137	0	53	40	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
108	2	sat-5-17	Sat_5_17	5	17	550	6928.137	0	53	40	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
109	2	sat-5-18	Sat_5_18	5	18	550	6928.137	0	53	40	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
110	2	sat-5-19	Sat_5_19	5	19	550	6928.137	0	53	40	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
111	2	sat-5-20	Sat_5_20	5	20	550	6928.137	0	53	40	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
112	2	sat-5-21	Sat_5_21	5	21	550	6928.137	0	53	40	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
113	2	sat-5-22	Sat_5_22	5	22	550	6928.137	0	53	40	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
114	2	sat-6-1	Sat_6_1	6	1	550	6928.137	0	53	50	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
115	2	sat-6-2	Sat_6_2	6	2	550	6928.137	0	53	50	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
116	2	sat-6-3	Sat_6_3	6	3	550	6928.137	0	53	50	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
117	2	sat-6-4	Sat_6_4	6	4	550	6928.137	0	53	50	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
118	2	sat-6-5	Sat_6_5	6	5	550	6928.137	0	53	50	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
119	2	sat-6-6	Sat_6_6	6	6	550	6928.137	0	53	50	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
120	2	sat-6-7	Sat_6_7	6	7	550	6928.137	0	53	50	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
121	2	sat-6-8	Sat_6_8	6	8	550	6928.137	0	53	50	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
122	2	sat-6-9	Sat_6_9	6	9	550	6928.137	0	53	50	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
123	2	sat-6-10	Sat_6_10	6	10	550	6928.137	0	53	50	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
124	2	sat-6-11	Sat_6_11	6	11	550	6928.137	0	53	50	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
125	2	sat-6-12	Sat_6_12	6	12	550	6928.137	0	53	50	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
126	2	sat-6-13	Sat_6_13	6	13	550	6928.137	0	53	50	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
127	2	sat-6-14	Sat_6_14	6	14	550	6928.137	0	53	50	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
128	2	sat-6-15	Sat_6_15	6	15	550	6928.137	0	53	50	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
129	2	sat-6-16	Sat_6_16	6	16	550	6928.137	0	53	50	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
130	2	sat-6-17	Sat_6_17	6	17	550	6928.137	0	53	50	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
131	2	sat-6-18	Sat_6_18	6	18	550	6928.137	0	53	50	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
132	2	sat-6-19	Sat_6_19	6	19	550	6928.137	0	53	50	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
133	2	sat-6-20	Sat_6_20	6	20	550	6928.137	0	53	50	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
134	2	sat-6-21	Sat_6_21	6	21	550	6928.137	0	53	50	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
135	2	sat-6-22	Sat_6_22	6	22	550	6928.137	0	53	50	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
136	2	sat-7-1	Sat_7_1	7	1	550	6928.137	0	53	60	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
137	2	sat-7-2	Sat_7_2	7	2	550	6928.137	0	53	60	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
138	2	sat-7-3	Sat_7_3	7	3	550	6928.137	0	53	60	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
139	2	sat-7-4	Sat_7_4	7	4	550	6928.137	0	53	60	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
140	2	sat-7-5	Sat_7_5	7	5	550	6928.137	0	53	60	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
141	2	sat-7-6	Sat_7_6	7	6	550	6928.137	0	53	60	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
142	2	sat-7-7	Sat_7_7	7	7	550	6928.137	0	53	60	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
143	2	sat-7-8	Sat_7_8	7	8	550	6928.137	0	53	60	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
144	2	sat-7-9	Sat_7_9	7	9	550	6928.137	0	53	60	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
145	2	sat-7-10	Sat_7_10	7	10	550	6928.137	0	53	60	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
146	2	sat-7-11	Sat_7_11	7	11	550	6928.137	0	53	60	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
147	2	sat-7-12	Sat_7_12	7	12	550	6928.137	0	53	60	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
148	2	sat-7-13	Sat_7_13	7	13	550	6928.137	0	53	60	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
149	2	sat-7-14	Sat_7_14	7	14	550	6928.137	0	53	60	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
150	2	sat-7-15	Sat_7_15	7	15	550	6928.137	0	53	60	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
151	2	sat-7-16	Sat_7_16	7	16	550	6928.137	0	53	60	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
152	2	sat-7-17	Sat_7_17	7	17	550	6928.137	0	53	60	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
153	2	sat-7-18	Sat_7_18	7	18	550	6928.137	0	53	60	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
154	2	sat-7-19	Sat_7_19	7	19	550	6928.137	0	53	60	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
155	2	sat-7-20	Sat_7_20	7	20	550	6928.137	0	53	60	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
156	2	sat-7-21	Sat_7_21	7	21	550	6928.137	0	53	60	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
157	2	sat-7-22	Sat_7_22	7	22	550	6928.137	0	53	60	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
158	2	sat-8-1	Sat_8_1	8	1	550	6928.137	0	53	70	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
159	2	sat-8-2	Sat_8_2	8	2	550	6928.137	0	53	70	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
160	2	sat-8-3	Sat_8_3	8	3	550	6928.137	0	53	70	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
161	2	sat-8-4	Sat_8_4	8	4	550	6928.137	0	53	70	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
162	2	sat-8-5	Sat_8_5	8	5	550	6928.137	0	53	70	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
163	2	sat-8-6	Sat_8_6	8	6	550	6928.137	0	53	70	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
164	2	sat-8-7	Sat_8_7	8	7	550	6928.137	0	53	70	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
165	2	sat-8-8	Sat_8_8	8	8	550	6928.137	0	53	70	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
166	2	sat-8-9	Sat_8_9	8	9	550	6928.137	0	53	70	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
167	2	sat-8-10	Sat_8_10	8	10	550	6928.137	0	53	70	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
168	2	sat-8-11	Sat_8_11	8	11	550	6928.137	0	53	70	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
169	2	sat-8-12	Sat_8_12	8	12	550	6928.137	0	53	70	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
170	2	sat-8-13	Sat_8_13	8	13	550	6928.137	0	53	70	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
171	2	sat-8-14	Sat_8_14	8	14	550	6928.137	0	53	70	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
172	2	sat-8-15	Sat_8_15	8	15	550	6928.137	0	53	70	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
173	2	sat-8-16	Sat_8_16	8	16	550	6928.137	0	53	70	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
174	2	sat-8-17	Sat_8_17	8	17	550	6928.137	0	53	70	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
175	2	sat-8-18	Sat_8_18	8	18	550	6928.137	0	53	70	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
176	2	sat-8-19	Sat_8_19	8	19	550	6928.137	0	53	70	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
177	2	sat-8-20	Sat_8_20	8	20	550	6928.137	0	53	70	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
178	2	sat-8-21	Sat_8_21	8	21	550	6928.137	0	53	70	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
179	2	sat-8-22	Sat_8_22	8	22	550	6928.137	0	53	70	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
180	2	sat-9-1	Sat_9_1	9	1	550	6928.137	0	53	80	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
181	2	sat-9-2	Sat_9_2	9	2	550	6928.137	0	53	80	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
182	2	sat-9-3	Sat_9_3	9	3	550	6928.137	0	53	80	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
183	2	sat-9-4	Sat_9_4	9	4	550	6928.137	0	53	80	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
184	2	sat-9-5	Sat_9_5	9	5	550	6928.137	0	53	80	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
185	2	sat-9-6	Sat_9_6	9	6	550	6928.137	0	53	80	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
186	2	sat-9-7	Sat_9_7	9	7	550	6928.137	0	53	80	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
187	2	sat-9-8	Sat_9_8	9	8	550	6928.137	0	53	80	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
188	2	sat-9-9	Sat_9_9	9	9	550	6928.137	0	53	80	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
189	2	sat-9-10	Sat_9_10	9	10	550	6928.137	0	53	80	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
190	2	sat-9-11	Sat_9_11	9	11	550	6928.137	0	53	80	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
191	2	sat-9-12	Sat_9_12	9	12	550	6928.137	0	53	80	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
192	2	sat-9-13	Sat_9_13	9	13	550	6928.137	0	53	80	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
193	2	sat-9-14	Sat_9_14	9	14	550	6928.137	0	53	80	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
194	2	sat-9-15	Sat_9_15	9	15	550	6928.137	0	53	80	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
195	2	sat-9-16	Sat_9_16	9	16	550	6928.137	0	53	80	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
196	2	sat-9-17	Sat_9_17	9	17	550	6928.137	0	53	80	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
197	2	sat-9-18	Sat_9_18	9	18	550	6928.137	0	53	80	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
198	2	sat-9-19	Sat_9_19	9	19	550	6928.137	0	53	80	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
199	2	sat-9-20	Sat_9_20	9	20	550	6928.137	0	53	80	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
200	2	sat-9-21	Sat_9_21	9	21	550	6928.137	0	53	80	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
201	2	sat-9-22	Sat_9_22	9	22	550	6928.137	0	53	80	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
202	2	sat-10-1	Sat_10_1	10	1	550	6928.137	0	53	90	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
203	2	sat-10-2	Sat_10_2	10	2	550	6928.137	0	53	90	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
204	2	sat-10-3	Sat_10_3	10	3	550	6928.137	0	53	90	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
205	2	sat-10-4	Sat_10_4	10	4	550	6928.137	0	53	90	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
206	2	sat-10-5	Sat_10_5	10	5	550	6928.137	0	53	90	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
207	2	sat-10-6	Sat_10_6	10	6	550	6928.137	0	53	90	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
208	2	sat-10-7	Sat_10_7	10	7	550	6928.137	0	53	90	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
209	2	sat-10-8	Sat_10_8	10	8	550	6928.137	0	53	90	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
210	2	sat-10-9	Sat_10_9	10	9	550	6928.137	0	53	90	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
211	2	sat-10-10	Sat_10_10	10	10	550	6928.137	0	53	90	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
212	2	sat-10-11	Sat_10_11	10	11	550	6928.137	0	53	90	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
213	2	sat-10-12	Sat_10_12	10	12	550	6928.137	0	53	90	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
214	2	sat-10-13	Sat_10_13	10	13	550	6928.137	0	53	90	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
215	2	sat-10-14	Sat_10_14	10	14	550	6928.137	0	53	90	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
216	2	sat-10-15	Sat_10_15	10	15	550	6928.137	0	53	90	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
217	2	sat-10-16	Sat_10_16	10	16	550	6928.137	0	53	90	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
218	2	sat-10-17	Sat_10_17	10	17	550	6928.137	0	53	90	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
219	2	sat-10-18	Sat_10_18	10	18	550	6928.137	0	53	90	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
220	2	sat-10-19	Sat_10_19	10	19	550	6928.137	0	53	90	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
221	2	sat-10-20	Sat_10_20	10	20	550	6928.137	0	53	90	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
222	2	sat-10-21	Sat_10_21	10	21	550	6928.137	0	53	90	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
223	2	sat-10-22	Sat_10_22	10	22	550	6928.137	0	53	90	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
224	2	sat-11-1	Sat_11_1	11	1	550	6928.137	0	53	100	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
225	2	sat-11-2	Sat_11_2	11	2	550	6928.137	0	53	100	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
226	2	sat-11-3	Sat_11_3	11	3	550	6928.137	0	53	100	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
227	2	sat-11-4	Sat_11_4	11	4	550	6928.137	0	53	100	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
228	2	sat-11-5	Sat_11_5	11	5	550	6928.137	0	53	100	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
229	2	sat-11-6	Sat_11_6	11	6	550	6928.137	0	53	100	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
230	2	sat-11-7	Sat_11_7	11	7	550	6928.137	0	53	100	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
231	2	sat-11-8	Sat_11_8	11	8	550	6928.137	0	53	100	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
232	2	sat-11-9	Sat_11_9	11	9	550	6928.137	0	53	100	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
233	2	sat-11-10	Sat_11_10	11	10	550	6928.137	0	53	100	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
234	2	sat-11-11	Sat_11_11	11	11	550	6928.137	0	53	100	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
235	2	sat-11-12	Sat_11_12	11	12	550	6928.137	0	53	100	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
236	2	sat-11-13	Sat_11_13	11	13	550	6928.137	0	53	100	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
237	2	sat-11-14	Sat_11_14	11	14	550	6928.137	0	53	100	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
238	2	sat-11-15	Sat_11_15	11	15	550	6928.137	0	53	100	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
239	2	sat-11-16	Sat_11_16	11	16	550	6928.137	0	53	100	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
240	2	sat-11-17	Sat_11_17	11	17	550	6928.137	0	53	100	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
241	2	sat-11-18	Sat_11_18	11	18	550	6928.137	0	53	100	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
242	2	sat-11-19	Sat_11_19	11	19	550	6928.137	0	53	100	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
243	2	sat-11-20	Sat_11_20	11	20	550	6928.137	0	53	100	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
244	2	sat-11-21	Sat_11_21	11	21	550	6928.137	0	53	100	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
245	2	sat-11-22	Sat_11_22	11	22	550	6928.137	0	53	100	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
246	2	sat-12-1	Sat_12_1	12	1	550	6928.137	0	53	110	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
247	2	sat-12-2	Sat_12_2	12	2	550	6928.137	0	53	110	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
248	2	sat-12-3	Sat_12_3	12	3	550	6928.137	0	53	110	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
249	2	sat-12-4	Sat_12_4	12	4	550	6928.137	0	53	110	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
250	2	sat-12-5	Sat_12_5	12	5	550	6928.137	0	53	110	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
251	2	sat-12-6	Sat_12_6	12	6	550	6928.137	0	53	110	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
252	2	sat-12-7	Sat_12_7	12	7	550	6928.137	0	53	110	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
253	2	sat-12-8	Sat_12_8	12	8	550	6928.137	0	53	110	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
254	2	sat-12-9	Sat_12_9	12	9	550	6928.137	0	53	110	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
255	2	sat-12-10	Sat_12_10	12	10	550	6928.137	0	53	110	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
256	2	sat-12-11	Sat_12_11	12	11	550	6928.137	0	53	110	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
257	2	sat-12-12	Sat_12_12	12	12	550	6928.137	0	53	110	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
258	2	sat-12-13	Sat_12_13	12	13	550	6928.137	0	53	110	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
259	2	sat-12-14	Sat_12_14	12	14	550	6928.137	0	53	110	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
260	2	sat-12-15	Sat_12_15	12	15	550	6928.137	0	53	110	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
261	2	sat-12-16	Sat_12_16	12	16	550	6928.137	0	53	110	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
262	2	sat-12-17	Sat_12_17	12	17	550	6928.137	0	53	110	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
263	2	sat-12-18	Sat_12_18	12	18	550	6928.137	0	53	110	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
264	2	sat-12-19	Sat_12_19	12	19	550	6928.137	0	53	110	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
265	2	sat-12-20	Sat_12_20	12	20	550	6928.137	0	53	110	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
266	2	sat-12-21	Sat_12_21	12	21	550	6928.137	0	53	110	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
267	2	sat-12-22	Sat_12_22	12	22	550	6928.137	0	53	110	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
268	2	sat-13-1	Sat_13_1	13	1	550	6928.137	0	53	120	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
269	2	sat-13-2	Sat_13_2	13	2	550	6928.137	0	53	120	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
270	2	sat-13-3	Sat_13_3	13	3	550	6928.137	0	53	120	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
271	2	sat-13-4	Sat_13_4	13	4	550	6928.137	0	53	120	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
272	2	sat-13-5	Sat_13_5	13	5	550	6928.137	0	53	120	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
273	2	sat-13-6	Sat_13_6	13	6	550	6928.137	0	53	120	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
274	2	sat-13-7	Sat_13_7	13	7	550	6928.137	0	53	120	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
275	2	sat-13-8	Sat_13_8	13	8	550	6928.137	0	53	120	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
276	2	sat-13-9	Sat_13_9	13	9	550	6928.137	0	53	120	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
277	2	sat-13-10	Sat_13_10	13	10	550	6928.137	0	53	120	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
278	2	sat-13-11	Sat_13_11	13	11	550	6928.137	0	53	120	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
279	2	sat-13-12	Sat_13_12	13	12	550	6928.137	0	53	120	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
280	2	sat-13-13	Sat_13_13	13	13	550	6928.137	0	53	120	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
281	2	sat-13-14	Sat_13_14	13	14	550	6928.137	0	53	120	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
282	2	sat-13-15	Sat_13_15	13	15	550	6928.137	0	53	120	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
283	2	sat-13-16	Sat_13_16	13	16	550	6928.137	0	53	120	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
284	2	sat-13-17	Sat_13_17	13	17	550	6928.137	0	53	120	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
285	2	sat-13-18	Sat_13_18	13	18	550	6928.137	0	53	120	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
286	2	sat-13-19	Sat_13_19	13	19	550	6928.137	0	53	120	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
287	2	sat-13-20	Sat_13_20	13	20	550	6928.137	0	53	120	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
288	2	sat-13-21	Sat_13_21	13	21	550	6928.137	0	53	120	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
289	2	sat-13-22	Sat_13_22	13	22	550	6928.137	0	53	120	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
290	2	sat-14-1	Sat_14_1	14	1	550	6928.137	0	53	130	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
291	2	sat-14-2	Sat_14_2	14	2	550	6928.137	0	53	130	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
292	2	sat-14-3	Sat_14_3	14	3	550	6928.137	0	53	130	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
293	2	sat-14-4	Sat_14_4	14	4	550	6928.137	0	53	130	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
294	2	sat-14-5	Sat_14_5	14	5	550	6928.137	0	53	130	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
295	2	sat-14-6	Sat_14_6	14	6	550	6928.137	0	53	130	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
296	2	sat-14-7	Sat_14_7	14	7	550	6928.137	0	53	130	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
297	2	sat-14-8	Sat_14_8	14	8	550	6928.137	0	53	130	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
298	2	sat-14-9	Sat_14_9	14	9	550	6928.137	0	53	130	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
299	2	sat-14-10	Sat_14_10	14	10	550	6928.137	0	53	130	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
300	2	sat-14-11	Sat_14_11	14	11	550	6928.137	0	53	130	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
301	2	sat-14-12	Sat_14_12	14	12	550	6928.137	0	53	130	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
302	2	sat-14-13	Sat_14_13	14	13	550	6928.137	0	53	130	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
303	2	sat-14-14	Sat_14_14	14	14	550	6928.137	0	53	130	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
304	2	sat-14-15	Sat_14_15	14	15	550	6928.137	0	53	130	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
305	2	sat-14-16	Sat_14_16	14	16	550	6928.137	0	53	130	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
306	2	sat-14-17	Sat_14_17	14	17	550	6928.137	0	53	130	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
307	2	sat-14-18	Sat_14_18	14	18	550	6928.137	0	53	130	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
308	2	sat-14-19	Sat_14_19	14	19	550	6928.137	0	53	130	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
309	2	sat-14-20	Sat_14_20	14	20	550	6928.137	0	53	130	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
310	2	sat-14-21	Sat_14_21	14	21	550	6928.137	0	53	130	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
311	2	sat-14-22	Sat_14_22	14	22	550	6928.137	0	53	130	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
312	2	sat-15-1	Sat_15_1	15	1	550	6928.137	0	53	140	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
313	2	sat-15-2	Sat_15_2	15	2	550	6928.137	0	53	140	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
314	2	sat-15-3	Sat_15_3	15	3	550	6928.137	0	53	140	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
315	2	sat-15-4	Sat_15_4	15	4	550	6928.137	0	53	140	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
316	2	sat-15-5	Sat_15_5	15	5	550	6928.137	0	53	140	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
317	2	sat-15-6	Sat_15_6	15	6	550	6928.137	0	53	140	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
318	2	sat-15-7	Sat_15_7	15	7	550	6928.137	0	53	140	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
319	2	sat-15-8	Sat_15_8	15	8	550	6928.137	0	53	140	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
320	2	sat-15-9	Sat_15_9	15	9	550	6928.137	0	53	140	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
321	2	sat-15-10	Sat_15_10	15	10	550	6928.137	0	53	140	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
322	2	sat-15-11	Sat_15_11	15	11	550	6928.137	0	53	140	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
323	2	sat-15-12	Sat_15_12	15	12	550	6928.137	0	53	140	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
324	2	sat-15-13	Sat_15_13	15	13	550	6928.137	0	53	140	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
325	2	sat-15-14	Sat_15_14	15	14	550	6928.137	0	53	140	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
326	2	sat-15-15	Sat_15_15	15	15	550	6928.137	0	53	140	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
327	2	sat-15-16	Sat_15_16	15	16	550	6928.137	0	53	140	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
328	2	sat-15-17	Sat_15_17	15	17	550	6928.137	0	53	140	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
329	2	sat-15-18	Sat_15_18	15	18	550	6928.137	0	53	140	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
330	2	sat-15-19	Sat_15_19	15	19	550	6928.137	0	53	140	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
331	2	sat-15-20	Sat_15_20	15	20	550	6928.137	0	53	140	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
332	2	sat-15-21	Sat_15_21	15	21	550	6928.137	0	53	140	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
333	2	sat-15-22	Sat_15_22	15	22	550	6928.137	0	53	140	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
334	2	sat-16-1	Sat_16_1	16	1	550	6928.137	0	53	150	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
335	2	sat-16-2	Sat_16_2	16	2	550	6928.137	0	53	150	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
336	2	sat-16-3	Sat_16_3	16	3	550	6928.137	0	53	150	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
337	2	sat-16-4	Sat_16_4	16	4	550	6928.137	0	53	150	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
338	2	sat-16-5	Sat_16_5	16	5	550	6928.137	0	53	150	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
339	2	sat-16-6	Sat_16_6	16	6	550	6928.137	0	53	150	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
340	2	sat-16-7	Sat_16_7	16	7	550	6928.137	0	53	150	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
341	2	sat-16-8	Sat_16_8	16	8	550	6928.137	0	53	150	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
342	2	sat-16-9	Sat_16_9	16	9	550	6928.137	0	53	150	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
343	2	sat-16-10	Sat_16_10	16	10	550	6928.137	0	53	150	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
344	2	sat-16-11	Sat_16_11	16	11	550	6928.137	0	53	150	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
345	2	sat-16-12	Sat_16_12	16	12	550	6928.137	0	53	150	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
346	2	sat-16-13	Sat_16_13	16	13	550	6928.137	0	53	150	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
347	2	sat-16-14	Sat_16_14	16	14	550	6928.137	0	53	150	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
348	2	sat-16-15	Sat_16_15	16	15	550	6928.137	0	53	150	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
349	2	sat-16-16	Sat_16_16	16	16	550	6928.137	0	53	150	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
350	2	sat-16-17	Sat_16_17	16	17	550	6928.137	0	53	150	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
351	2	sat-16-18	Sat_16_18	16	18	550	6928.137	0	53	150	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
352	2	sat-16-19	Sat_16_19	16	19	550	6928.137	0	53	150	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
353	2	sat-16-20	Sat_16_20	16	20	550	6928.137	0	53	150	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
354	2	sat-16-21	Sat_16_21	16	21	550	6928.137	0	53	150	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
355	2	sat-16-22	Sat_16_22	16	22	550	6928.137	0	53	150	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
356	2	sat-17-1	Sat_17_1	17	1	550	6928.137	0	53	160	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
357	2	sat-17-2	Sat_17_2	17	2	550	6928.137	0	53	160	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
358	2	sat-17-3	Sat_17_3	17	3	550	6928.137	0	53	160	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
359	2	sat-17-4	Sat_17_4	17	4	550	6928.137	0	53	160	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
360	2	sat-17-5	Sat_17_5	17	5	550	6928.137	0	53	160	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
361	2	sat-17-6	Sat_17_6	17	6	550	6928.137	0	53	160	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
362	2	sat-17-7	Sat_17_7	17	7	550	6928.137	0	53	160	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
363	2	sat-17-8	Sat_17_8	17	8	550	6928.137	0	53	160	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
364	2	sat-17-9	Sat_17_9	17	9	550	6928.137	0	53	160	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
365	2	sat-17-10	Sat_17_10	17	10	550	6928.137	0	53	160	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
366	2	sat-17-11	Sat_17_11	17	11	550	6928.137	0	53	160	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
367	2	sat-17-12	Sat_17_12	17	12	550	6928.137	0	53	160	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
368	2	sat-17-13	Sat_17_13	17	13	550	6928.137	0	53	160	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
369	2	sat-17-14	Sat_17_14	17	14	550	6928.137	0	53	160	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
370	2	sat-17-15	Sat_17_15	17	15	550	6928.137	0	53	160	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
371	2	sat-17-16	Sat_17_16	17	16	550	6928.137	0	53	160	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
372	2	sat-17-17	Sat_17_17	17	17	550	6928.137	0	53	160	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
373	2	sat-17-18	Sat_17_18	17	18	550	6928.137	0	53	160	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
374	2	sat-17-19	Sat_17_19	17	19	550	6928.137	0	53	160	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
375	2	sat-17-20	Sat_17_20	17	20	550	6928.137	0	53	160	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
376	2	sat-17-21	Sat_17_21	17	21	550	6928.137	0	53	160	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
377	2	sat-17-22	Sat_17_22	17	22	550	6928.137	0	53	160	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
378	2	sat-18-1	Sat_18_1	18	1	550	6928.137	0	53	170	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
379	2	sat-18-2	Sat_18_2	18	2	550	6928.137	0	53	170	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
380	2	sat-18-3	Sat_18_3	18	3	550	6928.137	0	53	170	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
381	2	sat-18-4	Sat_18_4	18	4	550	6928.137	0	53	170	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
382	2	sat-18-5	Sat_18_5	18	5	550	6928.137	0	53	170	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
383	2	sat-18-6	Sat_18_6	18	6	550	6928.137	0	53	170	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
384	2	sat-18-7	Sat_18_7	18	7	550	6928.137	0	53	170	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
385	2	sat-18-8	Sat_18_8	18	8	550	6928.137	0	53	170	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
386	2	sat-18-9	Sat_18_9	18	9	550	6928.137	0	53	170	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
387	2	sat-18-10	Sat_18_10	18	10	550	6928.137	0	53	170	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
388	2	sat-18-11	Sat_18_11	18	11	550	6928.137	0	53	170	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
389	2	sat-18-12	Sat_18_12	18	12	550	6928.137	0	53	170	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
390	2	sat-18-13	Sat_18_13	18	13	550	6928.137	0	53	170	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
391	2	sat-18-14	Sat_18_14	18	14	550	6928.137	0	53	170	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
392	2	sat-18-15	Sat_18_15	18	15	550	6928.137	0	53	170	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
393	2	sat-18-16	Sat_18_16	18	16	550	6928.137	0	53	170	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
394	2	sat-18-17	Sat_18_17	18	17	550	6928.137	0	53	170	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
395	2	sat-18-18	Sat_18_18	18	18	550	6928.137	0	53	170	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
396	2	sat-18-19	Sat_18_19	18	19	550	6928.137	0	53	170	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
397	2	sat-18-20	Sat_18_20	18	20	550	6928.137	0	53	170	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
398	2	sat-18-21	Sat_18_21	18	21	550	6928.137	0	53	170	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
399	2	sat-18-22	Sat_18_22	18	22	550	6928.137	0	53	170	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
400	2	sat-19-1	Sat_19_1	19	1	550	6928.137	0	53	180	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
401	2	sat-19-2	Sat_19_2	19	2	550	6928.137	0	53	180	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
402	2	sat-19-3	Sat_19_3	19	3	550	6928.137	0	53	180	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
403	2	sat-19-4	Sat_19_4	19	4	550	6928.137	0	53	180	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
404	2	sat-19-5	Sat_19_5	19	5	550	6928.137	0	53	180	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
405	2	sat-19-6	Sat_19_6	19	6	550	6928.137	0	53	180	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
406	2	sat-19-7	Sat_19_7	19	7	550	6928.137	0	53	180	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
407	2	sat-19-8	Sat_19_8	19	8	550	6928.137	0	53	180	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
408	2	sat-19-9	Sat_19_9	19	9	550	6928.137	0	53	180	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
409	2	sat-19-10	Sat_19_10	19	10	550	6928.137	0	53	180	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
410	2	sat-19-11	Sat_19_11	19	11	550	6928.137	0	53	180	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
411	2	sat-19-12	Sat_19_12	19	12	550	6928.137	0	53	180	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
412	2	sat-19-13	Sat_19_13	19	13	550	6928.137	0	53	180	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
413	2	sat-19-14	Sat_19_14	19	14	550	6928.137	0	53	180	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
414	2	sat-19-15	Sat_19_15	19	15	550	6928.137	0	53	180	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
415	2	sat-19-16	Sat_19_16	19	16	550	6928.137	0	53	180	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
416	2	sat-19-17	Sat_19_17	19	17	550	6928.137	0	53	180	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
417	2	sat-19-18	Sat_19_18	19	18	550	6928.137	0	53	180	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
418	2	sat-19-19	Sat_19_19	19	19	550	6928.137	0	53	180	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
419	2	sat-19-20	Sat_19_20	19	20	550	6928.137	0	53	180	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
420	2	sat-19-21	Sat_19_21	19	21	550	6928.137	0	53	180	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
421	2	sat-19-22	Sat_19_22	19	22	550	6928.137	0	53	180	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
422	2	sat-20-1	Sat_20_1	20	1	550	6928.137	0	53	190	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
423	2	sat-20-2	Sat_20_2	20	2	550	6928.137	0	53	190	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
424	2	sat-20-3	Sat_20_3	20	3	550	6928.137	0	53	190	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
425	2	sat-20-4	Sat_20_4	20	4	550	6928.137	0	53	190	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
426	2	sat-20-5	Sat_20_5	20	5	550	6928.137	0	53	190	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
427	2	sat-20-6	Sat_20_6	20	6	550	6928.137	0	53	190	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
428	2	sat-20-7	Sat_20_7	20	7	550	6928.137	0	53	190	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
429	2	sat-20-8	Sat_20_8	20	8	550	6928.137	0	53	190	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
430	2	sat-20-9	Sat_20_9	20	9	550	6928.137	0	53	190	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
431	2	sat-20-10	Sat_20_10	20	10	550	6928.137	0	53	190	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
432	2	sat-20-11	Sat_20_11	20	11	550	6928.137	0	53	190	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
433	2	sat-20-12	Sat_20_12	20	12	550	6928.137	0	53	190	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
434	2	sat-20-13	Sat_20_13	20	13	550	6928.137	0	53	190	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
435	2	sat-20-14	Sat_20_14	20	14	550	6928.137	0	53	190	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
436	2	sat-20-15	Sat_20_15	20	15	550	6928.137	0	53	190	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
437	2	sat-20-16	Sat_20_16	20	16	550	6928.137	0	53	190	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
438	2	sat-20-17	Sat_20_17	20	17	550	6928.137	0	53	190	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
439	2	sat-20-18	Sat_20_18	20	18	550	6928.137	0	53	190	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
440	2	sat-20-19	Sat_20_19	20	19	550	6928.137	0	53	190	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
441	2	sat-20-20	Sat_20_20	20	20	550	6928.137	0	53	190	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
442	2	sat-20-21	Sat_20_21	20	21	550	6928.137	0	53	190	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
443	2	sat-20-22	Sat_20_22	20	22	550	6928.137	0	53	190	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
444	2	sat-21-1	Sat_21_1	21	1	550	6928.137	0	53	200	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
445	2	sat-21-2	Sat_21_2	21	2	550	6928.137	0	53	200	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
446	2	sat-21-3	Sat_21_3	21	3	550	6928.137	0	53	200	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
447	2	sat-21-4	Sat_21_4	21	4	550	6928.137	0	53	200	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
448	2	sat-21-5	Sat_21_5	21	5	550	6928.137	0	53	200	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
449	2	sat-21-6	Sat_21_6	21	6	550	6928.137	0	53	200	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
450	2	sat-21-7	Sat_21_7	21	7	550	6928.137	0	53	200	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
451	2	sat-21-8	Sat_21_8	21	8	550	6928.137	0	53	200	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
452	2	sat-21-9	Sat_21_9	21	9	550	6928.137	0	53	200	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
453	2	sat-21-10	Sat_21_10	21	10	550	6928.137	0	53	200	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
454	2	sat-21-11	Sat_21_11	21	11	550	6928.137	0	53	200	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
455	2	sat-21-12	Sat_21_12	21	12	550	6928.137	0	53	200	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
456	2	sat-21-13	Sat_21_13	21	13	550	6928.137	0	53	200	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
457	2	sat-21-14	Sat_21_14	21	14	550	6928.137	0	53	200	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
458	2	sat-21-15	Sat_21_15	21	15	550	6928.137	0	53	200	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
459	2	sat-21-16	Sat_21_16	21	16	550	6928.137	0	53	200	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
460	2	sat-21-17	Sat_21_17	21	17	550	6928.137	0	53	200	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
461	2	sat-21-18	Sat_21_18	21	18	550	6928.137	0	53	200	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
462	2	sat-21-19	Sat_21_19	21	19	550	6928.137	0	53	200	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
463	2	sat-21-20	Sat_21_20	21	20	550	6928.137	0	53	200	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
464	2	sat-21-21	Sat_21_21	21	21	550	6928.137	0	53	200	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
465	2	sat-21-22	Sat_21_22	21	22	550	6928.137	0	53	200	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
466	2	sat-22-1	Sat_22_1	22	1	550	6928.137	0	53	210	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
467	2	sat-22-2	Sat_22_2	22	2	550	6928.137	0	53	210	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
468	2	sat-22-3	Sat_22_3	22	3	550	6928.137	0	53	210	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
469	2	sat-22-4	Sat_22_4	22	4	550	6928.137	0	53	210	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
470	2	sat-22-5	Sat_22_5	22	5	550	6928.137	0	53	210	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
471	2	sat-22-6	Sat_22_6	22	6	550	6928.137	0	53	210	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
472	2	sat-22-7	Sat_22_7	22	7	550	6928.137	0	53	210	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
473	2	sat-22-8	Sat_22_8	22	8	550	6928.137	0	53	210	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
474	2	sat-22-9	Sat_22_9	22	9	550	6928.137	0	53	210	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
475	2	sat-22-10	Sat_22_10	22	10	550	6928.137	0	53	210	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
476	2	sat-22-11	Sat_22_11	22	11	550	6928.137	0	53	210	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
477	2	sat-22-12	Sat_22_12	22	12	550	6928.137	0	53	210	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
478	2	sat-22-13	Sat_22_13	22	13	550	6928.137	0	53	210	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
479	2	sat-22-14	Sat_22_14	22	14	550	6928.137	0	53	210	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
480	2	sat-22-15	Sat_22_15	22	15	550	6928.137	0	53	210	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
481	2	sat-22-16	Sat_22_16	22	16	550	6928.137	0	53	210	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
482	2	sat-22-17	Sat_22_17	22	17	550	6928.137	0	53	210	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
483	2	sat-22-18	Sat_22_18	22	18	550	6928.137	0	53	210	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
484	2	sat-22-19	Sat_22_19	22	19	550	6928.137	0	53	210	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
485	2	sat-22-20	Sat_22_20	22	20	550	6928.137	0	53	210	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
486	2	sat-22-21	Sat_22_21	22	21	550	6928.137	0	53	210	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
487	2	sat-22-22	Sat_22_22	22	22	550	6928.137	0	53	210	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
488	2	sat-23-1	Sat_23_1	23	1	550	6928.137	0	53	220	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
489	2	sat-23-2	Sat_23_2	23	2	550	6928.137	0	53	220	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
490	2	sat-23-3	Sat_23_3	23	3	550	6928.137	0	53	220	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
491	2	sat-23-4	Sat_23_4	23	4	550	6928.137	0	53	220	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
492	2	sat-23-5	Sat_23_5	23	5	550	6928.137	0	53	220	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
493	2	sat-23-6	Sat_23_6	23	6	550	6928.137	0	53	220	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
494	2	sat-23-7	Sat_23_7	23	7	550	6928.137	0	53	220	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
495	2	sat-23-8	Sat_23_8	23	8	550	6928.137	0	53	220	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
496	2	sat-23-9	Sat_23_9	23	9	550	6928.137	0	53	220	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
497	2	sat-23-10	Sat_23_10	23	10	550	6928.137	0	53	220	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
498	2	sat-23-11	Sat_23_11	23	11	550	6928.137	0	53	220	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
499	2	sat-23-12	Sat_23_12	23	12	550	6928.137	0	53	220	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
500	2	sat-23-13	Sat_23_13	23	13	550	6928.137	0	53	220	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
501	2	sat-23-14	Sat_23_14	23	14	550	6928.137	0	53	220	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
502	2	sat-23-15	Sat_23_15	23	15	550	6928.137	0	53	220	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
503	2	sat-23-16	Sat_23_16	23	16	550	6928.137	0	53	220	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
504	2	sat-23-17	Sat_23_17	23	17	550	6928.137	0	53	220	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
505	2	sat-23-18	Sat_23_18	23	18	550	6928.137	0	53	220	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
506	2	sat-23-19	Sat_23_19	23	19	550	6928.137	0	53	220	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
507	2	sat-23-20	Sat_23_20	23	20	550	6928.137	0	53	220	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
508	2	sat-23-21	Sat_23_21	23	21	550	6928.137	0	53	220	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
509	2	sat-23-22	Sat_23_22	23	22	550	6928.137	0	53	220	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
510	2	sat-24-1	Sat_24_1	24	1	550	6928.137	0	53	230	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
511	2	sat-24-2	Sat_24_2	24	2	550	6928.137	0	53	230	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
512	2	sat-24-3	Sat_24_3	24	3	550	6928.137	0	53	230	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
513	2	sat-24-4	Sat_24_4	24	4	550	6928.137	0	53	230	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
514	2	sat-24-5	Sat_24_5	24	5	550	6928.137	0	53	230	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
515	2	sat-24-6	Sat_24_6	24	6	550	6928.137	0	53	230	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
516	2	sat-24-7	Sat_24_7	24	7	550	6928.137	0	53	230	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
517	2	sat-24-8	Sat_24_8	24	8	550	6928.137	0	53	230	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
518	2	sat-24-9	Sat_24_9	24	9	550	6928.137	0	53	230	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
519	2	sat-24-10	Sat_24_10	24	10	550	6928.137	0	53	230	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
520	2	sat-24-11	Sat_24_11	24	11	550	6928.137	0	53	230	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
521	2	sat-24-12	Sat_24_12	24	12	550	6928.137	0	53	230	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
522	2	sat-24-13	Sat_24_13	24	13	550	6928.137	0	53	230	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
523	2	sat-24-14	Sat_24_14	24	14	550	6928.137	0	53	230	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
524	2	sat-24-15	Sat_24_15	24	15	550	6928.137	0	53	230	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
525	2	sat-24-16	Sat_24_16	24	16	550	6928.137	0	53	230	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
526	2	sat-24-17	Sat_24_17	24	17	550	6928.137	0	53	230	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
527	2	sat-24-18	Sat_24_18	24	18	550	6928.137	0	53	230	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
528	2	sat-24-19	Sat_24_19	24	19	550	6928.137	0	53	230	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
529	2	sat-24-20	Sat_24_20	24	20	550	6928.137	0	53	230	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
530	2	sat-24-21	Sat_24_21	24	21	550	6928.137	0	53	230	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
531	2	sat-24-22	Sat_24_22	24	22	550	6928.137	0	53	230	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
532	2	sat-25-1	Sat_25_1	25	1	550	6928.137	0	53	240	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
533	2	sat-25-2	Sat_25_2	25	2	550	6928.137	0	53	240	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
534	2	sat-25-3	Sat_25_3	25	3	550	6928.137	0	53	240	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
535	2	sat-25-4	Sat_25_4	25	4	550	6928.137	0	53	240	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
536	2	sat-25-5	Sat_25_5	25	5	550	6928.137	0	53	240	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
537	2	sat-25-6	Sat_25_6	25	6	550	6928.137	0	53	240	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
538	2	sat-25-7	Sat_25_7	25	7	550	6928.137	0	53	240	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
539	2	sat-25-8	Sat_25_8	25	8	550	6928.137	0	53	240	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
540	2	sat-25-9	Sat_25_9	25	9	550	6928.137	0	53	240	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
541	2	sat-25-10	Sat_25_10	25	10	550	6928.137	0	53	240	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
542	2	sat-25-11	Sat_25_11	25	11	550	6928.137	0	53	240	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
543	2	sat-25-12	Sat_25_12	25	12	550	6928.137	0	53	240	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
544	2	sat-25-13	Sat_25_13	25	13	550	6928.137	0	53	240	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
545	2	sat-25-14	Sat_25_14	25	14	550	6928.137	0	53	240	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
546	2	sat-25-15	Sat_25_15	25	15	550	6928.137	0	53	240	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
547	2	sat-25-16	Sat_25_16	25	16	550	6928.137	0	53	240	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
548	2	sat-25-17	Sat_25_17	25	17	550	6928.137	0	53	240	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
549	2	sat-25-18	Sat_25_18	25	18	550	6928.137	0	53	240	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
550	2	sat-25-19	Sat_25_19	25	19	550	6928.137	0	53	240	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
551	2	sat-25-20	Sat_25_20	25	20	550	6928.137	0	53	240	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
552	2	sat-25-21	Sat_25_21	25	21	550	6928.137	0	53	240	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
553	2	sat-25-22	Sat_25_22	25	22	550	6928.137	0	53	240	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
554	2	sat-26-1	Sat_26_1	26	1	550	6928.137	0	53	250	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
555	2	sat-26-2	Sat_26_2	26	2	550	6928.137	0	53	250	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
556	2	sat-26-3	Sat_26_3	26	3	550	6928.137	0	53	250	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
557	2	sat-26-4	Sat_26_4	26	4	550	6928.137	0	53	250	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
558	2	sat-26-5	Sat_26_5	26	5	550	6928.137	0	53	250	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
559	2	sat-26-6	Sat_26_6	26	6	550	6928.137	0	53	250	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
560	2	sat-26-7	Sat_26_7	26	7	550	6928.137	0	53	250	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
561	2	sat-26-8	Sat_26_8	26	8	550	6928.137	0	53	250	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
562	2	sat-26-9	Sat_26_9	26	9	550	6928.137	0	53	250	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
563	2	sat-26-10	Sat_26_10	26	10	550	6928.137	0	53	250	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
564	2	sat-26-11	Sat_26_11	26	11	550	6928.137	0	53	250	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
565	2	sat-26-12	Sat_26_12	26	12	550	6928.137	0	53	250	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
566	2	sat-26-13	Sat_26_13	26	13	550	6928.137	0	53	250	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
567	2	sat-26-14	Sat_26_14	26	14	550	6928.137	0	53	250	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
568	2	sat-26-15	Sat_26_15	26	15	550	6928.137	0	53	250	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
569	2	sat-26-16	Sat_26_16	26	16	550	6928.137	0	53	250	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
570	2	sat-26-17	Sat_26_17	26	17	550	6928.137	0	53	250	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
571	2	sat-26-18	Sat_26_18	26	18	550	6928.137	0	53	250	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
572	2	sat-26-19	Sat_26_19	26	19	550	6928.137	0	53	250	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
573	2	sat-26-20	Sat_26_20	26	20	550	6928.137	0	53	250	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
574	2	sat-26-21	Sat_26_21	26	21	550	6928.137	0	53	250	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
575	2	sat-26-22	Sat_26_22	26	22	550	6928.137	0	53	250	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
576	2	sat-27-1	Sat_27_1	27	1	550	6928.137	0	53	260	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
577	2	sat-27-2	Sat_27_2	27	2	550	6928.137	0	53	260	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
578	2	sat-27-3	Sat_27_3	27	3	550	6928.137	0	53	260	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
579	2	sat-27-4	Sat_27_4	27	4	550	6928.137	0	53	260	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
580	2	sat-27-5	Sat_27_5	27	5	550	6928.137	0	53	260	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
581	2	sat-27-6	Sat_27_6	27	6	550	6928.137	0	53	260	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
582	2	sat-27-7	Sat_27_7	27	7	550	6928.137	0	53	260	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
583	2	sat-27-8	Sat_27_8	27	8	550	6928.137	0	53	260	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
584	2	sat-27-9	Sat_27_9	27	9	550	6928.137	0	53	260	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
585	2	sat-27-10	Sat_27_10	27	10	550	6928.137	0	53	260	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
586	2	sat-27-11	Sat_27_11	27	11	550	6928.137	0	53	260	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
587	2	sat-27-12	Sat_27_12	27	12	550	6928.137	0	53	260	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
588	2	sat-27-13	Sat_27_13	27	13	550	6928.137	0	53	260	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
589	2	sat-27-14	Sat_27_14	27	14	550	6928.137	0	53	260	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
590	2	sat-27-15	Sat_27_15	27	15	550	6928.137	0	53	260	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
591	2	sat-27-16	Sat_27_16	27	16	550	6928.137	0	53	260	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
592	2	sat-27-17	Sat_27_17	27	17	550	6928.137	0	53	260	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
593	2	sat-27-18	Sat_27_18	27	18	550	6928.137	0	53	260	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
594	2	sat-27-19	Sat_27_19	27	19	550	6928.137	0	53	260	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
595	2	sat-27-20	Sat_27_20	27	20	550	6928.137	0	53	260	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
596	2	sat-27-21	Sat_27_21	27	21	550	6928.137	0	53	260	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
597	2	sat-27-22	Sat_27_22	27	22	550	6928.137	0	53	260	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
598	2	sat-28-1	Sat_28_1	28	1	550	6928.137	0	53	270	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
599	2	sat-28-2	Sat_28_2	28	2	550	6928.137	0	53	270	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
600	2	sat-28-3	Sat_28_3	28	3	550	6928.137	0	53	270	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
601	2	sat-28-4	Sat_28_4	28	4	550	6928.137	0	53	270	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
602	2	sat-28-5	Sat_28_5	28	5	550	6928.137	0	53	270	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
603	2	sat-28-6	Sat_28_6	28	6	550	6928.137	0	53	270	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
604	2	sat-28-7	Sat_28_7	28	7	550	6928.137	0	53	270	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
605	2	sat-28-8	Sat_28_8	28	8	550	6928.137	0	53	270	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
606	2	sat-28-9	Sat_28_9	28	9	550	6928.137	0	53	270	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
607	2	sat-28-10	Sat_28_10	28	10	550	6928.137	0	53	270	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
608	2	sat-28-11	Sat_28_11	28	11	550	6928.137	0	53	270	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
609	2	sat-28-12	Sat_28_12	28	12	550	6928.137	0	53	270	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
610	2	sat-28-13	Sat_28_13	28	13	550	6928.137	0	53	270	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
611	2	sat-28-14	Sat_28_14	28	14	550	6928.137	0	53	270	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
612	2	sat-28-15	Sat_28_15	28	15	550	6928.137	0	53	270	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
613	2	sat-28-16	Sat_28_16	28	16	550	6928.137	0	53	270	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
614	2	sat-28-17	Sat_28_17	28	17	550	6928.137	0	53	270	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
615	2	sat-28-18	Sat_28_18	28	18	550	6928.137	0	53	270	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
616	2	sat-28-19	Sat_28_19	28	19	550	6928.137	0	53	270	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
617	2	sat-28-20	Sat_28_20	28	20	550	6928.137	0	53	270	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
618	2	sat-28-21	Sat_28_21	28	21	550	6928.137	0	53	270	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
619	2	sat-28-22	Sat_28_22	28	22	550	6928.137	0	53	270	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
620	2	sat-29-1	Sat_29_1	29	1	550	6928.137	0	53	280	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
621	2	sat-29-2	Sat_29_2	29	2	550	6928.137	0	53	280	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
622	2	sat-29-3	Sat_29_3	29	3	550	6928.137	0	53	280	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
623	2	sat-29-4	Sat_29_4	29	4	550	6928.137	0	53	280	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
624	2	sat-29-5	Sat_29_5	29	5	550	6928.137	0	53	280	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
625	2	sat-29-6	Sat_29_6	29	6	550	6928.137	0	53	280	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
626	2	sat-29-7	Sat_29_7	29	7	550	6928.137	0	53	280	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
627	2	sat-29-8	Sat_29_8	29	8	550	6928.137	0	53	280	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
628	2	sat-29-9	Sat_29_9	29	9	550	6928.137	0	53	280	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
629	2	sat-29-10	Sat_29_10	29	10	550	6928.137	0	53	280	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
630	2	sat-29-11	Sat_29_11	29	11	550	6928.137	0	53	280	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
631	2	sat-29-12	Sat_29_12	29	12	550	6928.137	0	53	280	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
632	2	sat-29-13	Sat_29_13	29	13	550	6928.137	0	53	280	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
633	2	sat-29-14	Sat_29_14	29	14	550	6928.137	0	53	280	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
634	2	sat-29-15	Sat_29_15	29	15	550	6928.137	0	53	280	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
635	2	sat-29-16	Sat_29_16	29	16	550	6928.137	0	53	280	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
636	2	sat-29-17	Sat_29_17	29	17	550	6928.137	0	53	280	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
637	2	sat-29-18	Sat_29_18	29	18	550	6928.137	0	53	280	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
638	2	sat-29-19	Sat_29_19	29	19	550	6928.137	0	53	280	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
639	2	sat-29-20	Sat_29_20	29	20	550	6928.137	0	53	280	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
640	2	sat-29-21	Sat_29_21	29	21	550	6928.137	0	53	280	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
641	2	sat-29-22	Sat_29_22	29	22	550	6928.137	0	53	280	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
642	2	sat-30-1	Sat_30_1	30	1	550	6928.137	0	53	290	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
643	2	sat-30-2	Sat_30_2	30	2	550	6928.137	0	53	290	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
644	2	sat-30-3	Sat_30_3	30	3	550	6928.137	0	53	290	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
645	2	sat-30-4	Sat_30_4	30	4	550	6928.137	0	53	290	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
646	2	sat-30-5	Sat_30_5	30	5	550	6928.137	0	53	290	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
647	2	sat-30-6	Sat_30_6	30	6	550	6928.137	0	53	290	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
648	2	sat-30-7	Sat_30_7	30	7	550	6928.137	0	53	290	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
649	2	sat-30-8	Sat_30_8	30	8	550	6928.137	0	53	290	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
650	2	sat-30-9	Sat_30_9	30	9	550	6928.137	0	53	290	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
651	2	sat-30-10	Sat_30_10	30	10	550	6928.137	0	53	290	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
652	2	sat-30-11	Sat_30_11	30	11	550	6928.137	0	53	290	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
653	2	sat-30-12	Sat_30_12	30	12	550	6928.137	0	53	290	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
654	2	sat-30-13	Sat_30_13	30	13	550	6928.137	0	53	290	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
655	2	sat-30-14	Sat_30_14	30	14	550	6928.137	0	53	290	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
656	2	sat-30-15	Sat_30_15	30	15	550	6928.137	0	53	290	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
657	2	sat-30-16	Sat_30_16	30	16	550	6928.137	0	53	290	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
658	2	sat-30-17	Sat_30_17	30	17	550	6928.137	0	53	290	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
659	2	sat-30-18	Sat_30_18	30	18	550	6928.137	0	53	290	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
660	2	sat-30-19	Sat_30_19	30	19	550	6928.137	0	53	290	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
661	2	sat-30-20	Sat_30_20	30	20	550	6928.137	0	53	290	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
662	2	sat-30-21	Sat_30_21	30	21	550	6928.137	0	53	290	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
663	2	sat-30-22	Sat_30_22	30	22	550	6928.137	0	53	290	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
664	2	sat-31-1	Sat_31_1	31	1	550	6928.137	0	53	300	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
665	2	sat-31-2	Sat_31_2	31	2	550	6928.137	0	53	300	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
666	2	sat-31-3	Sat_31_3	31	3	550	6928.137	0	53	300	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
667	2	sat-31-4	Sat_31_4	31	4	550	6928.137	0	53	300	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
668	2	sat-31-5	Sat_31_5	31	5	550	6928.137	0	53	300	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
669	2	sat-31-6	Sat_31_6	31	6	550	6928.137	0	53	300	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
670	2	sat-31-7	Sat_31_7	31	7	550	6928.137	0	53	300	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
671	2	sat-31-8	Sat_31_8	31	8	550	6928.137	0	53	300	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
672	2	sat-31-9	Sat_31_9	31	9	550	6928.137	0	53	300	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
673	2	sat-31-10	Sat_31_10	31	10	550	6928.137	0	53	300	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
674	2	sat-31-11	Sat_31_11	31	11	550	6928.137	0	53	300	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
675	2	sat-31-12	Sat_31_12	31	12	550	6928.137	0	53	300	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
676	2	sat-31-13	Sat_31_13	31	13	550	6928.137	0	53	300	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
677	2	sat-31-14	Sat_31_14	31	14	550	6928.137	0	53	300	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
678	2	sat-31-15	Sat_31_15	31	15	550	6928.137	0	53	300	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
679	2	sat-31-16	Sat_31_16	31	16	550	6928.137	0	53	300	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
680	2	sat-31-17	Sat_31_17	31	17	550	6928.137	0	53	300	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
681	2	sat-31-18	Sat_31_18	31	18	550	6928.137	0	53	300	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
682	2	sat-31-19	Sat_31_19	31	19	550	6928.137	0	53	300	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
683	2	sat-31-20	Sat_31_20	31	20	550	6928.137	0	53	300	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
684	2	sat-31-21	Sat_31_21	31	21	550	6928.137	0	53	300	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
685	2	sat-31-22	Sat_31_22	31	22	550	6928.137	0	53	300	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
686	2	sat-32-1	Sat_32_1	32	1	550	6928.137	0	53	310	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
687	2	sat-32-2	Sat_32_2	32	2	550	6928.137	0	53	310	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
688	2	sat-32-3	Sat_32_3	32	3	550	6928.137	0	53	310	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
689	2	sat-32-4	Sat_32_4	32	4	550	6928.137	0	53	310	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
690	2	sat-32-5	Sat_32_5	32	5	550	6928.137	0	53	310	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
691	2	sat-32-6	Sat_32_6	32	6	550	6928.137	0	53	310	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
692	2	sat-32-7	Sat_32_7	32	7	550	6928.137	0	53	310	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
693	2	sat-32-8	Sat_32_8	32	8	550	6928.137	0	53	310	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
694	2	sat-32-9	Sat_32_9	32	9	550	6928.137	0	53	310	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
695	2	sat-32-10	Sat_32_10	32	10	550	6928.137	0	53	310	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
696	2	sat-32-11	Sat_32_11	32	11	550	6928.137	0	53	310	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
697	2	sat-32-12	Sat_32_12	32	12	550	6928.137	0	53	310	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
698	2	sat-32-13	Sat_32_13	32	13	550	6928.137	0	53	310	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
699	2	sat-32-14	Sat_32_14	32	14	550	6928.137	0	53	310	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
700	2	sat-32-15	Sat_32_15	32	15	550	6928.137	0	53	310	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
701	2	sat-32-16	Sat_32_16	32	16	550	6928.137	0	53	310	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
702	2	sat-32-17	Sat_32_17	32	17	550	6928.137	0	53	310	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
703	2	sat-32-18	Sat_32_18	32	18	550	6928.137	0	53	310	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
704	2	sat-32-19	Sat_32_19	32	19	550	6928.137	0	53	310	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
705	2	sat-32-20	Sat_32_20	32	20	550	6928.137	0	53	310	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
706	2	sat-32-21	Sat_32_21	32	21	550	6928.137	0	53	310	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
707	2	sat-32-22	Sat_32_22	32	22	550	6928.137	0	53	310	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
708	2	sat-33-1	Sat_33_1	33	1	550	6928.137	0	53	320	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
709	2	sat-33-2	Sat_33_2	33	2	550	6928.137	0	53	320	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
710	2	sat-33-3	Sat_33_3	33	3	550	6928.137	0	53	320	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
711	2	sat-33-4	Sat_33_4	33	4	550	6928.137	0	53	320	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
712	2	sat-33-5	Sat_33_5	33	5	550	6928.137	0	53	320	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
713	2	sat-33-6	Sat_33_6	33	6	550	6928.137	0	53	320	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
714	2	sat-33-7	Sat_33_7	33	7	550	6928.137	0	53	320	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
715	2	sat-33-8	Sat_33_8	33	8	550	6928.137	0	53	320	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
716	2	sat-33-9	Sat_33_9	33	9	550	6928.137	0	53	320	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
717	2	sat-33-10	Sat_33_10	33	10	550	6928.137	0	53	320	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
718	2	sat-33-11	Sat_33_11	33	11	550	6928.137	0	53	320	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
719	2	sat-33-12	Sat_33_12	33	12	550	6928.137	0	53	320	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
720	2	sat-33-13	Sat_33_13	33	13	550	6928.137	0	53	320	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
721	2	sat-33-14	Sat_33_14	33	14	550	6928.137	0	53	320	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
722	2	sat-33-15	Sat_33_15	33	15	550	6928.137	0	53	320	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
723	2	sat-33-16	Sat_33_16	33	16	550	6928.137	0	53	320	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
724	2	sat-33-17	Sat_33_17	33	17	550	6928.137	0	53	320	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
725	2	sat-33-18	Sat_33_18	33	18	550	6928.137	0	53	320	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
726	2	sat-33-19	Sat_33_19	33	19	550	6928.137	0	53	320	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
727	2	sat-33-20	Sat_33_20	33	20	550	6928.137	0	53	320	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
728	2	sat-33-21	Sat_33_21	33	21	550	6928.137	0	53	320	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
729	2	sat-33-22	Sat_33_22	33	22	550	6928.137	0	53	320	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
730	2	sat-34-1	Sat_34_1	34	1	550	6928.137	0	53	330	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
731	2	sat-34-2	Sat_34_2	34	2	550	6928.137	0	53	330	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
732	2	sat-34-3	Sat_34_3	34	3	550	6928.137	0	53	330	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
733	2	sat-34-4	Sat_34_4	34	4	550	6928.137	0	53	330	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
734	2	sat-34-5	Sat_34_5	34	5	550	6928.137	0	53	330	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
735	2	sat-34-6	Sat_34_6	34	6	550	6928.137	0	53	330	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
736	2	sat-34-7	Sat_34_7	34	7	550	6928.137	0	53	330	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
737	2	sat-34-8	Sat_34_8	34	8	550	6928.137	0	53	330	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
738	2	sat-34-9	Sat_34_9	34	9	550	6928.137	0	53	330	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
739	2	sat-34-10	Sat_34_10	34	10	550	6928.137	0	53	330	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
740	2	sat-34-11	Sat_34_11	34	11	550	6928.137	0	53	330	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
741	2	sat-34-12	Sat_34_12	34	12	550	6928.137	0	53	330	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
742	2	sat-34-13	Sat_34_13	34	13	550	6928.137	0	53	330	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
743	2	sat-34-14	Sat_34_14	34	14	550	6928.137	0	53	330	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
744	2	sat-34-15	Sat_34_15	34	15	550	6928.137	0	53	330	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
745	2	sat-34-16	Sat_34_16	34	16	550	6928.137	0	53	330	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
746	2	sat-34-17	Sat_34_17	34	17	550	6928.137	0	53	330	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
747	2	sat-34-18	Sat_34_18	34	18	550	6928.137	0	53	330	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
748	2	sat-34-19	Sat_34_19	34	19	550	6928.137	0	53	330	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
749	2	sat-34-20	Sat_34_20	34	20	550	6928.137	0	53	330	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
750	2	sat-34-21	Sat_34_21	34	21	550	6928.137	0	53	330	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
751	2	sat-34-22	Sat_34_22	34	22	550	6928.137	0	53	330	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
752	2	sat-35-1	Sat_35_1	35	1	550	6928.137	0	53	340	0	0	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
753	2	sat-35-2	Sat_35_2	35	2	550	6928.137	0	53	340	0	16.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
754	2	sat-35-3	Sat_35_3	35	3	550	6928.137	0	53	340	0	32.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
755	2	sat-35-4	Sat_35_4	35	4	550	6928.137	0	53	340	0	49.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
756	2	sat-35-5	Sat_35_5	35	5	550	6928.137	0	53	340	0	65.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
757	2	sat-35-6	Sat_35_6	35	6	550	6928.137	0	53	340	0	81.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
758	2	sat-35-7	Sat_35_7	35	7	550	6928.137	0	53	340	0	98.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
759	2	sat-35-8	Sat_35_8	35	8	550	6928.137	0	53	340	0	114.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
760	2	sat-35-9	Sat_35_9	35	9	550	6928.137	0	53	340	0	130.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
761	2	sat-35-10	Sat_35_10	35	10	550	6928.137	0	53	340	0	147.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
762	2	sat-35-11	Sat_35_11	35	11	550	6928.137	0	53	340	0	163.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
763	2	sat-35-12	Sat_35_12	35	12	550	6928.137	0	53	340	0	180	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
764	2	sat-35-13	Sat_35_13	35	13	550	6928.137	0	53	340	0	196.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
765	2	sat-35-14	Sat_35_14	35	14	550	6928.137	0	53	340	0	212.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
766	2	sat-35-15	Sat_35_15	35	15	550	6928.137	0	53	340	0	229.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
767	2	sat-35-16	Sat_35_16	35	16	550	6928.137	0	53	340	0	245.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
768	2	sat-35-17	Sat_35_17	35	17	550	6928.137	0	53	340	0	261.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
769	2	sat-35-18	Sat_35_18	35	18	550	6928.137	0	53	340	0	278.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
770	2	sat-35-19	Sat_35_19	35	19	550	6928.137	0	53	340	0	294.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
771	2	sat-35-20	Sat_35_20	35	20	550	6928.137	0	53	340	0	310.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
772	2	sat-35-21	Sat_35_21	35	21	550	6928.137	0	53	340	0	327.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
773	2	sat-35-22	Sat_35_22	35	22	550	6928.137	0	53	340	0	343.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
774	2	sat-36-1	Sat_36_1	36	1	550	6928.137	0	53	350	0	8.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
775	2	sat-36-2	Sat_36_2	36	2	550	6928.137	0	53	350	0	24.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
776	2	sat-36-3	Sat_36_3	36	3	550	6928.137	0	53	350	0	40.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
777	2	sat-36-4	Sat_36_4	36	4	550	6928.137	0	53	350	0	57.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
778	2	sat-36-5	Sat_36_5	36	5	550	6928.137	0	53	350	0	73.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
779	2	sat-36-6	Sat_36_6	36	6	550	6928.137	0	53	350	0	90	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
780	2	sat-36-7	Sat_36_7	36	7	550	6928.137	0	53	350	0	106.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
781	2	sat-36-8	Sat_36_8	36	8	550	6928.137	0	53	350	0	122.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
782	2	sat-36-9	Sat_36_9	36	9	550	6928.137	0	53	350	0	139.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
783	2	sat-36-10	Sat_36_10	36	10	550	6928.137	0	53	350	0	155.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
784	2	sat-36-11	Sat_36_11	36	11	550	6928.137	0	53	350	0	171.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
785	2	sat-36-12	Sat_36_12	36	12	550	6928.137	0	53	350	0	188.181818	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
786	2	sat-36-13	Sat_36_13	36	13	550	6928.137	0	53	350	0	204.545455	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
787	2	sat-36-14	Sat_36_14	36	14	550	6928.137	0	53	350	0	220.909091	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
788	2	sat-36-15	Sat_36_15	36	15	550	6928.137	0	53	350	0	237.272727	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
789	2	sat-36-16	Sat_36_16	36	16	550	6928.137	0	53	350	0	253.636364	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
790	2	sat-36-17	Sat_36_17	36	17	550	6928.137	0	53	350	0	270	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
791	2	sat-36-18	Sat_36_18	36	18	550	6928.137	0	53	350	0	286.363636	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
792	2	sat-36-19	Sat_36_19	36	19	550	6928.137	0	53	350	0	302.727273	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
793	2	sat-36-20	Sat_36_20	36	20	550	6928.137	0	53	350	0	319.090909	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
794	2	sat-36-21	Sat_36_21	36	21	550	6928.137	0	53	350	0	335.454545	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
795	2	sat-36-22	Sat_36_22	36	22	550	6928.137	0	53	350	0	351.818182	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
796	3	sat-3-4	Sat_3_4	3	4	550	6928.137	0	53	240	0	54	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
797	3	sat-3-18	Sat_3_18	3	18	550	6928.137	0	53	240	0	306	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
798	3	sat-1-9	Sat_1_9	1	9	550	6928.137	0	53	0	0	144	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
799	3	sat-2-4	Sat_2_4	2	4	550	6928.137	0	53	120	0	54	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
800	3	sat-2-18	Sat_2_18	2	18	550	6928.137	0	53	120	0	306	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
801	3	sat-3-20	Sat_3_20	3	20	550	6928.137	0	53	240	0	342	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
802	3	sat-3-14	Sat_3_14	3	14	550	6928.137	0	53	240	0	234	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
803	3	sat-1-7	Sat_1_7	1	7	550	6928.137	0	53	0	0	108	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
804	3	sat-3-5	Sat_3_5	3	5	550	6928.137	0	53	240	0	72	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
805	3	sat-2-12	Sat_2_12	2	12	550	6928.137	0	53	120	0	198	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
806	3	sat-1-10	Sat_1_10	1	10	550	6928.137	0	53	0	0	162	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
807	3	sat-3-17	Sat_3_17	3	17	550	6928.137	0	53	240	0	288	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
808	3	sat-1-6	Sat_1_6	1	6	550	6928.137	0	53	0	0	90	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
809	3	sat-1-8	Sat_1_8	1	8	550	6928.137	0	53	0	0	126	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
810	3	sat-3-11	Sat_3_11	3	11	550	6928.137	0	53	240	0	180	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
811	3	sat-2-13	Sat_2_13	2	13	550	6928.137	0	53	120	0	216	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
812	3	sat-1-17	Sat_1_17	1	17	550	6928.137	0	53	0	0	288	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
813	3	sat-2-15	Sat_2_15	2	15	550	6928.137	0	53	120	0	252	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
814	3	sat-2-10	Sat_2_10	2	10	550	6928.137	0	53	120	0	162	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
815	3	sat-2-17	Sat_2_17	2	17	550	6928.137	0	53	120	0	288	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
816	3	sat-2-8	Sat_2_8	2	8	550	6928.137	0	53	120	0	126	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
817	3	sat-2-3	Sat_2_3	2	3	550	6928.137	0	53	120	0	36	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
818	3	sat-2-14	Sat_2_14	2	14	550	6928.137	0	53	120	0	234	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
819	3	sat-2-7	Sat_2_7	2	7	550	6928.137	0	53	120	0	108	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
820	3	sat-1-18	Sat_1_18	1	18	550	6928.137	0	53	0	0	306	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
821	3	sat-1-2	Sat_1_2	1	2	550	6928.137	0	53	0	0	18	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
822	3	sat-2-1	Sat_2_1	2	1	550	6928.137	0	53	120	0	0	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
823	3	sat-1-4	Sat_1_4	1	4	550	6928.137	0	53	0	0	54	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
824	3	sat-3-19	Sat_3_19	3	19	550	6928.137	0	53	240	0	324	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
825	3	sat-3-7	Sat_3_7	3	7	550	6928.137	0	53	240	0	108	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
826	3	sat-3-1	Sat_3_1	3	1	550	6928.137	0	53	240	0	0	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
827	3	sat-3-8	Sat_3_8	3	8	550	6928.137	0	53	240	0	126	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
828	3	sat-1-20	Sat_1_20	1	20	550	6928.137	0	53	0	0	342	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
829	3	sat-3-2	Sat_3_2	3	2	550	6928.137	0	53	240	0	18	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
830	3	sat-2-20	Sat_2_20	2	20	550	6928.137	0	53	120	0	342	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
831	3	sat-3-15	Sat_3_15	3	15	550	6928.137	0	53	240	0	252	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
832	3	sat-3-3	Sat_3_3	3	3	550	6928.137	0	53	240	0	36	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
833	3	sat-2-2	Sat_2_2	2	2	550	6928.137	0	53	120	0	18	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
834	3	sat-3-9	Sat_3_9	3	9	550	6928.137	0	53	240	0	144	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
835	3	sat-1-12	Sat_1_12	1	12	550	6928.137	0	53	0	0	198	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
836	3	sat-3-16	Sat_3_16	3	16	550	6928.137	0	53	240	0	270	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
837	3	sat-2-19	Sat_2_19	2	19	550	6928.137	0	53	120	0	324	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
838	3	sat-2-11	Sat_2_11	2	11	550	6928.137	0	53	120	0	180	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
839	3	sat-2-16	Sat_2_16	2	16	550	6928.137	0	53	120	0	270	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
840	3	sat-2-6	Sat_2_6	2	6	550	6928.137	0	53	120	0	90	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
841	3	sat-1-13	Sat_1_13	1	13	550	6928.137	0	53	0	0	216	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
842	3	sat-1-11	Sat_1_11	1	11	550	6928.137	0	53	0	0	180	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
843	3	sat-1-3	Sat_1_3	1	3	550	6928.137	0	53	0	0	36	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
844	3	sat-3-13	Sat_3_13	3	13	550	6928.137	0	53	240	0	216	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
845	3	sat-1-19	Sat_1_19	1	19	550	6928.137	0	53	0	0	324	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
846	3	sat-1-5	Sat_1_5	1	5	550	6928.137	0	53	0	0	72	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
847	3	sat-1-1	Sat_1_1	1	1	550	6928.137	0	53	0	0	0	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
848	3	sat-3-6	Sat_3_6	3	6	550	6928.137	0	53	240	0	90	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
849	3	sat-1-14	Sat_1_14	1	14	550	6928.137	0	53	0	0	234	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
850	3	sat-3-12	Sat_3_12	3	12	550	6928.137	0	53	240	0	198	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
851	3	sat-1-15	Sat_1_15	1	15	550	6928.137	0	53	0	0	252	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
852	3	sat-2-9	Sat_2_9	2	9	550	6928.137	0	53	120	0	144	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
853	3	sat-2-5	Sat_2_5	2	5	550	6928.137	0	53	120	0	72	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
854	3	sat-3-10	Sat_3_10	3	10	550	6928.137	0	53	240	0	162	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
855	3	sat-1-16	Sat_1_16	1	16	550	6928.137	0	53	0	0	270	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
\.


--
-- Data for Name: scenarios; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.scenarios (id, name, epoch, start_time, end_time, alt_km, inc_deg, n_planes, n_sats_per_plane, sensor_config, created_at, updated_at, deleted_at) FROM stdin;
1	Scenario5	15 Dec 2025 00:00:00	15 Dec 2025 00:00:00	16 Dec 2025 00:00:00	550	53	36	22	{"type": "SimpleConic", "coneHalfAngleDeg": 30.0}	2026-08-21 11:53:22.746103+08	2026-08-21 11:53:22.746103+08	\N
2	Scenario5_full_36x22	15 Dec 2025 00:00:00 UTCG	15 Dec 2025 00:00:00	16 Dec 2025 00:00:00	550	53	36	22	{"type": "SimpleConic", "coneHalfAngleDeg": 30}	2026-08-21 11:53:22.782913+08	2026-08-21 11:53:22.782913+08	\N
3	Scenario60_3x20	15 Jul 2026 00:00:00 UTCG	15 Jul 2026 00:00:00	16 Jul 2026 00:00:00	550	53	3	20	{"type": "SimpleConic", "coneHalfAngleDeg": 30}	2026-08-21 11:53:23.427305+08	2026-08-21 11:53:23.427305+08	\N
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: satellite_user
--

COPY public.schema_migrations (version, dirty) FROM stdin;
10	f
\.


--
-- Name: object_detection_task_artifacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.object_detection_task_artifacts_id_seq', 1, false);


--
-- Name: object_detection_task_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.object_detection_task_logs_id_seq', 1, false);


--
-- Name: object_detection_task_stages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.object_detection_task_stages_id_seq', 1, false);


--
-- Name: object_detection_tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.object_detection_tasks_id_seq', 1, false);


--
-- Name: remote_sensing_task_artifacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.remote_sensing_task_artifacts_id_seq', 1, false);


--
-- Name: remote_sensing_task_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.remote_sensing_task_logs_id_seq', 1, false);


--
-- Name: remote_sensing_task_stages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.remote_sensing_task_stages_id_seq', 1, false);


--
-- Name: remote_sensing_tasks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.remote_sensing_tasks_id_seq', 1, false);


--
-- Name: router_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.router_links_id_seq', 59, true);


--
-- Name: router_nodes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.router_nodes_id_seq', 15, true);


--
-- Name: satellite_delay_edges_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.satellite_delay_edges_id_seq', 1, false);


--
-- Name: satellite_states_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.satellite_states_id_seq', 1, false);


--
-- Name: satellites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.satellites_id_seq', 855, true);


--
-- Name: scenarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: satellite_user
--

SELECT pg_catalog.setval('public.scenarios_id_seq', 3, true);


--
-- Name: object_detection_task_artifacts object_detection_task_artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_artifacts
    ADD CONSTRAINT object_detection_task_artifacts_pkey PRIMARY KEY (id);


--
-- Name: object_detection_task_logs object_detection_task_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_logs
    ADD CONSTRAINT object_detection_task_logs_pkey PRIMARY KEY (id);


--
-- Name: object_detection_task_stages object_detection_task_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_stages
    ADD CONSTRAINT object_detection_task_stages_pkey PRIMARY KEY (id);


--
-- Name: object_detection_tasks object_detection_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_tasks
    ADD CONSTRAINT object_detection_tasks_pkey PRIMARY KEY (id);


--
-- Name: remote_sensing_task_artifacts remote_sensing_task_artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_artifacts
    ADD CONSTRAINT remote_sensing_task_artifacts_pkey PRIMARY KEY (id);


--
-- Name: remote_sensing_task_logs remote_sensing_task_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_logs
    ADD CONSTRAINT remote_sensing_task_logs_pkey PRIMARY KEY (id);


--
-- Name: remote_sensing_task_stages remote_sensing_task_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_stages
    ADD CONSTRAINT remote_sensing_task_stages_pkey PRIMARY KEY (id);


--
-- Name: remote_sensing_tasks remote_sensing_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_tasks
    ADD CONSTRAINT remote_sensing_tasks_pkey PRIMARY KEY (id);


--
-- Name: router_links router_links_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.router_links
    ADD CONSTRAINT router_links_pkey PRIMARY KEY (id);


--
-- Name: router_nodes router_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.router_nodes
    ADD CONSTRAINT router_nodes_pkey PRIMARY KEY (id);


--
-- Name: satellite_delay_edges satellite_delay_edges_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellite_delay_edges
    ADD CONSTRAINT satellite_delay_edges_pkey PRIMARY KEY (id);


--
-- Name: satellite_states satellite_states_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellite_states
    ADD CONSTRAINT satellite_states_pkey PRIMARY KEY (id);


--
-- Name: satellites satellites_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellites
    ADD CONSTRAINT satellites_pkey PRIMARY KEY (id);


--
-- Name: scenarios scenarios_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.scenarios
    ADD CONSTRAINT scenarios_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: idx_delay_edges_scenario_a_b; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_delay_edges_scenario_a_b ON public.satellite_delay_edges USING btree (scenario_id, a_id, b_id);


--
-- Name: idx_object_detection_task_artifacts_task; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_object_detection_task_artifacts_task ON public.object_detection_task_artifacts USING btree (task_id);


--
-- Name: idx_object_detection_task_logs_task; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_object_detection_task_logs_task ON public.object_detection_task_logs USING btree (task_id);


--
-- Name: idx_object_detection_task_stages_task; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_object_detection_task_stages_task ON public.object_detection_task_stages USING btree (task_id, stage_order);


--
-- Name: idx_object_detection_tasks_status; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_object_detection_tasks_status ON public.object_detection_tasks USING btree (status);


--
-- Name: idx_remote_sensing_task_artifacts_task; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_remote_sensing_task_artifacts_task ON public.remote_sensing_task_artifacts USING btree (task_id);


--
-- Name: idx_remote_sensing_task_logs_task; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_remote_sensing_task_logs_task ON public.remote_sensing_task_logs USING btree (task_id);


--
-- Name: idx_remote_sensing_task_stages_task; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_remote_sensing_task_stages_task ON public.remote_sensing_task_stages USING btree (task_id, stage_order);


--
-- Name: idx_remote_sensing_tasks_executed_sat_id; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_remote_sensing_tasks_executed_sat_id ON public.remote_sensing_tasks USING btree (executed_sat_id);


--
-- Name: idx_remote_sensing_tasks_satellite; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_remote_sensing_tasks_satellite ON public.remote_sensing_tasks USING btree (satellite_id);


--
-- Name: idx_remote_sensing_tasks_scenario; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_remote_sensing_tasks_scenario ON public.remote_sensing_tasks USING btree (scenario_id);


--
-- Name: idx_remote_sensing_tasks_status; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_remote_sensing_tasks_status ON public.remote_sensing_tasks USING btree (status);


--
-- Name: idx_router_links_scenario_src; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_router_links_scenario_src ON public.router_links USING btree (scenario_id, src_router);


--
-- Name: idx_router_nodes_scenario_router; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE UNIQUE INDEX idx_router_nodes_scenario_router ON public.router_nodes USING btree (scenario_id, router_id);


--
-- Name: idx_sat_states_scenario_sat_time; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_sat_states_scenario_sat_time ON public.satellite_states USING btree (scenario_id, sat_id, t_utc);


--
-- Name: idx_satellites_deleted_at; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_satellites_deleted_at ON public.satellites USING btree (deleted_at);


--
-- Name: idx_satellites_plane_sat_index; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_satellites_plane_sat_index ON public.satellites USING btree (plane_index, sat_index_in_plane);


--
-- Name: idx_satellites_scenario_sat_id; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_satellites_scenario_sat_id ON public.satellites USING btree (scenario_id, sat_id);


--
-- Name: idx_scenarios_deleted_at; Type: INDEX; Schema: public; Owner: satellite_user
--

CREATE INDEX idx_scenarios_deleted_at ON public.scenarios USING btree (deleted_at);


--
-- Name: object_detection_task_stages trg_set_updated_at_object_detection_task_stages; Type: TRIGGER; Schema: public; Owner: satellite_user
--

CREATE TRIGGER trg_set_updated_at_object_detection_task_stages BEFORE UPDATE ON public.object_detection_task_stages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: object_detection_tasks trg_set_updated_at_object_detection_tasks; Type: TRIGGER; Schema: public; Owner: satellite_user
--

CREATE TRIGGER trg_set_updated_at_object_detection_tasks BEFORE UPDATE ON public.object_detection_tasks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: remote_sensing_task_stages trg_set_updated_at_remote_sensing_task_stages; Type: TRIGGER; Schema: public; Owner: satellite_user
--

CREATE TRIGGER trg_set_updated_at_remote_sensing_task_stages BEFORE UPDATE ON public.remote_sensing_task_stages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: remote_sensing_tasks trg_set_updated_at_remote_sensing_tasks; Type: TRIGGER; Schema: public; Owner: satellite_user
--

CREATE TRIGGER trg_set_updated_at_remote_sensing_tasks BEFORE UPDATE ON public.remote_sensing_tasks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: satellites trg_set_updated_at_satellites; Type: TRIGGER; Schema: public; Owner: satellite_user
--

CREATE TRIGGER trg_set_updated_at_satellites BEFORE UPDATE ON public.satellites FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: scenarios trg_set_updated_at_scenarios; Type: TRIGGER; Schema: public; Owner: satellite_user
--

CREATE TRIGGER trg_set_updated_at_scenarios BEFORE UPDATE ON public.scenarios FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: object_detection_task_artifacts object_detection_task_artifacts_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_artifacts
    ADD CONSTRAINT object_detection_task_artifacts_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.object_detection_tasks(id) ON DELETE CASCADE;


--
-- Name: object_detection_task_logs object_detection_task_logs_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_logs
    ADD CONSTRAINT object_detection_task_logs_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.object_detection_tasks(id) ON DELETE CASCADE;


--
-- Name: object_detection_task_stages object_detection_task_stages_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.object_detection_task_stages
    ADD CONSTRAINT object_detection_task_stages_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.object_detection_tasks(id) ON DELETE CASCADE;


--
-- Name: remote_sensing_task_artifacts remote_sensing_task_artifacts_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_artifacts
    ADD CONSTRAINT remote_sensing_task_artifacts_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.remote_sensing_tasks(id) ON DELETE CASCADE;


--
-- Name: remote_sensing_task_logs remote_sensing_task_logs_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_logs
    ADD CONSTRAINT remote_sensing_task_logs_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.remote_sensing_tasks(id) ON DELETE CASCADE;


--
-- Name: remote_sensing_task_stages remote_sensing_task_stages_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_task_stages
    ADD CONSTRAINT remote_sensing_task_stages_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.remote_sensing_tasks(id) ON DELETE CASCADE;


--
-- Name: remote_sensing_tasks remote_sensing_tasks_satellite_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_tasks
    ADD CONSTRAINT remote_sensing_tasks_satellite_id_fkey FOREIGN KEY (satellite_id) REFERENCES public.satellites(id) ON DELETE SET NULL;


--
-- Name: remote_sensing_tasks remote_sensing_tasks_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.remote_sensing_tasks
    ADD CONSTRAINT remote_sensing_tasks_scenario_id_fkey FOREIGN KEY (scenario_id) REFERENCES public.scenarios(id) ON DELETE SET NULL;


--
-- Name: router_links router_links_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.router_links
    ADD CONSTRAINT router_links_scenario_id_fkey FOREIGN KEY (scenario_id) REFERENCES public.scenarios(id) ON DELETE CASCADE;


--
-- Name: router_nodes router_nodes_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.router_nodes
    ADD CONSTRAINT router_nodes_scenario_id_fkey FOREIGN KEY (scenario_id) REFERENCES public.scenarios(id) ON DELETE CASCADE;


--
-- Name: satellite_delay_edges satellite_delay_edges_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellite_delay_edges
    ADD CONSTRAINT satellite_delay_edges_scenario_id_fkey FOREIGN KEY (scenario_id) REFERENCES public.scenarios(id) ON DELETE CASCADE;


--
-- Name: satellite_states satellite_states_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellite_states
    ADD CONSTRAINT satellite_states_scenario_id_fkey FOREIGN KEY (scenario_id) REFERENCES public.scenarios(id) ON DELETE CASCADE;


--
-- Name: satellites satellites_scenario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: satellite_user
--

ALTER TABLE ONLY public.satellites
    ADD CONSTRAINT satellites_scenario_id_fkey FOREIGN KEY (scenario_id) REFERENCES public.scenarios(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

