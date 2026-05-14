drop schema if exists poc cascade;
create schema poc;

-- 1. Компании
create table poc.company (
    company_id bigserial primary key,
    inn text not null unique,
    ogrn text,
    company_label text,
    region text,
    region_taxcode text,
    okved text,
    okved_section text,
    creation_date date,
    dissolution_date date,
    age numeric,
    sample_bucket text
);

-- 2. Финансовая отчётность: одна строка = компания + год
create table poc.financial_report (
    report_id bigserial primary key,
    company_id bigint not null references poc.company(company_id),
    inn text not null,
    ogrn text,
    year int not null,

    eligible numeric,
    filed numeric,
    imputed numeric,
    outlier numeric,

    revenue numeric,
    net_profit numeric,
    assets numeric,
    equity numeric,
    longterm_liab numeric,
    shortterm_liab numeric,
    payables numeric,
    cash numeric,

    unique (company_id, year)
);

-- 3. Рассчитанные признаки компании
create table poc.company_features (
    company_id bigint primary key references poc.company(company_id),
    inn text not null unique,
    ogrn text,
    sample_bucket text,

    revenue_2023 numeric,
    revenue_2024 numeric,
    revenue_drop_2024_pct numeric,

    net_profit_2023 numeric,
    net_profit_2024 numeric,

    assets_2023 numeric,
    assets_2024 numeric,
    assets_drop_2024_pct numeric,

    equity_2023 numeric,
    equity_2024 numeric,

    filed_2023 numeric,
    filed_2024 numeric,
    imputed_2023 numeric,
    imputed_2024 numeric,
    outlier_2023 numeric,
    outlier_2024 numeric,

    risk_revenue_drop_gt_30 boolean,
    risk_negative_profit boolean,
    risk_assets_drop_gt_25 boolean,
    risk_negative_equity boolean,
    risk_data_quality_issue boolean,

    risk_count int
);

-- 4. Справочник риск-факторов
create table poc.risk_factor (
    risk_factor_id bigserial primary key,
    code text not null unique,
    title text not null,
    description text,
    severity text not null
);

-- 5. Финансовые факты
create table poc.financial_fact (
    fact_id bigserial primary key,
    company_id bigint not null references poc.company(company_id),
    fact_type text not null,
    report_year int,
    value numeric,
    unit text,
    description text,
    source text not null default 'RFSD'
);

-- 6. Связь компании с риск-фактором
create table poc.company_risk (
    company_risk_id bigserial primary key,
    company_id bigint not null references poc.company(company_id),
    risk_factor_id bigint not null references poc.risk_factor(risk_factor_id),
    fact_id bigint references poc.financial_fact(fact_id),
    confidence numeric not null default 1.0,
    explanation text
);

-- 7. Узлы графа
create table poc.graph_node (
    node_id text primary key,
    node_type text not null,
    label text not null,
    ref_table text,
    ref_id text,
    metadata jsonb not null default '{}'::jsonb
);

-- 8. Рёбра графа
create table poc.graph_edge (
    edge_id bigserial primary key,
    source_node_id text not null references poc.graph_node(node_id),
    target_node_id text not null references poc.graph_node(node_id),
    edge_type text not null,
    weight numeric not null default 1.0,
    confidence numeric not null default 1.0,
    metadata jsonb not null default '{}'::jsonb,
    unique (source_node_id, target_node_id, edge_type)
);

create index idx_financial_report_inn_year on poc.financial_report(inn, year);
create index idx_financial_fact_company on poc.financial_fact(company_id);
create index idx_company_risk_company on poc.company_risk(company_id);
create index idx_graph_edge_source on poc.graph_edge(source_node_id);
create index idx_graph_edge_target on poc.graph_edge(target_node_id);
create index idx_graph_node_type on poc.graph_node(node_type);
