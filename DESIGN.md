erDiagram

    COMPANY ||--o{ DRIVER : pertenece_a
    USER ||--|| DRIVER : es
    DRIVER ||--o{ VEHICLE : conduce
    USER ||--o{ TRIP : solicita
    DRIVER ||--o{ TRIP : realiza
    TRIP ||--o{ OFFER : genera
    DRIVER ||--o{ OFFER : recibe
    TRIP ||--o{ TRIP_STATUS_HISTORY : tiene

    COMPANY {
        BIGINT id_company PK
        VARCHAR nombre
    }

    USER {
        BIGINT id_user PK
        VARCHAR nombre
        VARCHAR email
        ENUM rol
    }

    DRIVER {
        BIGINT id_driver PK, FK
        BIGINT id_company FK
        DECIMAL rating
    }

    VEHICLE {
        BIGINT id_vehicle PK
        BIGINT id_driver FK
        VARCHAR matricula
        VARCHAR modelo
    }

    TRIP {
        BIGINT id_trip PK
        BIGINT id_rider FK
        BIGINT id_driver FK
        ENUM estado
    }

    OFFER {
        BIGINT id_offer PK
        BIGINT id_trip FK
        BIGINT id_driver FK
        ENUM estado
    }

    TRIP_STATUS_HISTORY {
        BIGINT id_history PK
        BIGINT id_trip FK
        ENUM estado
        DATETIME created_at
    }