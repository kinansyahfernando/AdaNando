-- Skema AdaNando v3 (aman dijalankan berulang kali). Dijalankan oleh: npm run migrate
-- Waktu disimpan sebagai milidetik epoch (BIGINT) supaya tidak ada masalah zona waktu.

CREATE TABLE IF NOT EXISTS users (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  name     VARCHAR(100) NOT NULL,
  email    VARCHAR(150) NOT NULL UNIQUE,
  password VARCHAR(100) NOT NULL,
  role     VARCHAR(10)  NOT NULL DEFAULT 'siswa'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS classes (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(50) NOT NULL UNIQUE,
  created_at BIGINT      NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS subtests (
  id      VARCHAR(20)  NOT NULL PRIMARY KEY,
  code    VARCHAR(10)  NOT NULL,
  name    VARCHAR(100) NOT NULL,
  is_utbk TINYINT(1)   NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS questions (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(40) NULL UNIQUE,
  subtest_id    VARCHAR(20) NOT NULL,
  passage       TEXT        NULL,
  text          TEXT        NOT NULL,
  options       TEXT        NOT NULL,
  correct_index TINYINT     NOT NULL,
  explanation   TEXT        NULL,
  difficulty    TINYINT     NOT NULL DEFAULT 2,
  usage_type    VARCHAR(10) NOT NULL DEFAULT 'semua',
  is_active     TINYINT(1)  NOT NULL DEFAULT 1,
  created_by    INT         NULL,
  created_at    BIGINT      NOT NULL,
  updated_at    BIGINT      NULL,
  KEY idx_subtest (subtest_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exams (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  title             VARCHAR(150) NOT NULL,
  description       TEXT         NULL,
  kind              VARCHAR(10)  NOT NULL DEFAULT 'sekolah',
  sections          TEXT         NOT NULL,
  status            VARCHAR(10)  NOT NULL DEFAULT 'draft',
  start_at          BIGINT       NULL,
  end_at            BIGINT       NULL,
  access_token      VARCHAR(12)  NULL,
  max_attempts      INT          NOT NULL DEFAULT 1,
  max_violations    INT          NOT NULL DEFAULT 2,
  shuffle_questions TINYINT(1)   NOT NULL DEFAULT 1,
  shuffle_options   TINYINT(1)   NOT NULL DEFAULT 1,
  result_mode       VARCHAR(10)  NOT NULL DEFAULT 'score',
  created_by        INT          NULL,
  created_at        BIGINT       NOT NULL,
  updated_at        BIGINT       NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_classes (
  exam_id  INT NOT NULL,
  class_id INT NOT NULL,
  PRIMARY KEY (exam_id, class_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_attempts (
  id                 INT AUTO_INCREMENT PRIMARY KEY,
  exam_id            INT          NOT NULL,
  user_id            INT          NOT NULL,
  status             VARCHAR(10)  NOT NULL DEFAULT 'running',
  current_section    INT          NOT NULL DEFAULT 0,
  section_started_at BIGINT       NOT NULL,
  started_at         BIGINT       NOT NULL,
  finished_at        BIGINT       NULL,
  end_reason         VARCHAR(12)  NULL,
  violations         INT          NOT NULL DEFAULT 0,
  last_violation_at  BIGINT       NULL,
  last_seen_at       BIGINT       NULL,
  extra_seconds      INT          NOT NULL DEFAULT 0,
  ip                 VARCHAR(64)  NULL,
  user_agent         VARCHAR(255) NULL,
  plan               MEDIUMTEXT   NOT NULL,
  answers            MEDIUMTEXT   NULL,
  KEY idx_exam_user (exam_id, user_id),
  KEY idx_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS attempt_sections (
  attempt_id  INT         NOT NULL,
  section_idx INT         NOT NULL,
  subtest_id  VARCHAR(20) NOT NULL,
  total       INT         NOT NULL,
  correct     INT         NOT NULL,
  wrong       INT         NOT NULL,
  points      INT         NOT NULL,
  closed_at   BIGINT      NOT NULL,
  PRIMARY KEY (attempt_id, section_idx)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS violation_logs (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  attempt_id INT          NOT NULL,
  user_id    INT          NOT NULL,
  type       VARCHAR(20)  NOT NULL,
  counted    TINYINT(1)   NOT NULL DEFAULT 1,
  detail     VARCHAR(200) NULL,
  created_at BIGINT       NOT NULL,
  KEY idx_attempt (attempt_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS audit_logs (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  actor_id   INT          NULL,
  action     VARCHAR(40)  NOT NULL,
  target     VARCHAR(80)  NULL,
  detail     VARCHAR(500) NULL,
  ip         VARCHAR(64)  NULL,
  created_at BIGINT       NOT NULL,
  KEY idx_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
