-- Baseline schema: the database as it stood on 2026-10-05, before migrations were introduced.
-- Generated from pg_dump --schema-only, with the 125 duplicate UNIQUE constraints that
-- sequelize.sync({ alter: true }) had accumulated collapsed to one per column.
-- Never edit this file: change the schema with a new migration instead.

CREATE TABLE public.ai_models (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    slug character varying(100) NOT NULL,
    category character varying(50),
    display_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.chats (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title character varying(255) DEFAULT 'New chat'::character varying,
    excerpt text,
    model_id uuid,
    category character varying(50),
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chat_id uuid NOT NULL,
    role character varying(20) NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    model_id uuid,
    tokens_input integer DEFAULT 0,
    tokens_output integer DEFAULT 0,
    created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    revenuecat_customer_id character varying(255),
    product_id character varying(100),
    status character varying(50) DEFAULT 'active'::character varying,
    started_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.usage_limits (
    user_id uuid NOT NULL,
    limit_amount numeric(10,2) DEFAULT 16,
    limit_period character varying(20) DEFAULT 'monthly'::character varying,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.usage_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    model_id uuid,
    record_date date NOT NULL,
    tokens_input bigint DEFAULT 0,
    tokens_output bigint DEFAULT 0,
    cost numeric(12,4) DEFAULT 0,
    created_at timestamp with time zone NOT NULL
);

CREATE TABLE public.user_settings (
    user_id uuid NOT NULL,
    theme character varying(20) DEFAULT 'dark'::character varying,
    font_size character varying(20) DEFAULT 'medium'::character varying,
    enter_to_send boolean DEFAULT true,
    show_timestamps boolean DEFAULT true,
    read_aloud boolean DEFAULT false,
    ai_voice_model character varying(100),
    system_prompt text,
    temperature numeric(3,2) DEFAULT 0.7,
    token_threshold_80 boolean DEFAULT true,
    token_threshold_90 boolean DEFAULT true,
    token_threshold_100 boolean DEFAULT true,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255),
    name character varying(255),
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    google_id character varying(255),
    github_id character varying(255),
    apple_id character varying(255),
    avatar_url character varying(500),
    type character varying(50) DEFAULT 'user'::character varying
);

ALTER TABLE ONLY public.ai_models
    ADD CONSTRAINT ai_models_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.ai_models
    ADD CONSTRAINT ai_models_slug_key UNIQUE (slug);

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT usage_limits_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.usage_records
    ADD CONSTRAINT usage_records_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.usage_records
    ADD CONSTRAINT usage_records_user_id_model_id_record_date_key UNIQUE (user_id, model_id, record_date);

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_apple_id_key UNIQUE (apple_id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_github_id_key UNIQUE (github_id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_google_id_key UNIQUE (google_id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);

CREATE INDEX idx_chats_created_at ON public.chats USING btree (user_id, created_at DESC);

CREATE INDEX idx_chats_search ON public.chats USING gin (to_tsvector('english'::regconfig, (((((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(excerpt, ''::text)) || ' '::text) || (COALESCE(category, ''::character varying))::text)));

CREATE INDEX idx_chats_user_id ON public.chats USING btree (user_id);

CREATE INDEX idx_messages_chat_id ON public.messages USING btree (chat_id);

CREATE INDEX idx_messages_created_at ON public.messages USING btree (chat_id, created_at);

CREATE INDEX idx_subscriptions_user_id ON public.subscriptions USING btree (user_id);

CREATE INDEX idx_usage_user_date ON public.usage_records USING btree (user_id, record_date DESC);

CREATE INDEX idx_usage_user_model ON public.usage_records USING btree (user_id, model_id);

CREATE INDEX idx_users_apple_id ON public.users USING btree (apple_id);

CREATE INDEX idx_users_email ON public.users USING btree (email);

CREATE INDEX idx_users_github_id ON public.users USING btree (github_id);

CREATE INDEX idx_users_google_id ON public.users USING btree (google_id);

CREATE UNIQUE INDEX usage_records_user_id_model_id_record_date ON public.usage_records USING btree (user_id, model_id, record_date);

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_model_id_fkey FOREIGN KEY (model_id) REFERENCES public.ai_models(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_model_id_fkey FOREIGN KEY (model_id) REFERENCES public.ai_models(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT usage_limits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.usage_records
    ADD CONSTRAINT usage_records_model_id_fkey FOREIGN KEY (model_id) REFERENCES public.ai_models(id) ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE ONLY public.usage_records
    ADD CONSTRAINT usage_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
