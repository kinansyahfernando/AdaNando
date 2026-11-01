-- Tabel Try Out Mandiri (timer dari server) dan riwayat hasil untuk halaman Potensi.
-- Jalankan:  node scripts/create-tryout-tables.js

CREATE TABLE IF NOT EXISTS tryout_attempts (
  id                 INT AUTO_INCREMENT PRIMARY KEY,
  user_id            INT         NOT NULL,
  status             VARCHAR(10) NOT NULL DEFAULT 'running',
  current_section    INT         NOT NULL DEFAULT 0,
  section_started_at BIGINT      NOT NULL,
  started_at         BIGINT      NOT NULL,
  finished_at        BIGINT      NULL,
  end_reason         VARCHAR(12) NULL,
  KEY idx_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS practice_results (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT         NOT NULL,
  subtest_id VARCHAR(20) NOT NULL,
  source     VARCHAR(10) NOT NULL,
  attempt_id INT         NULL,
  total      INT         NOT NULL,
  correct    INT         NOT NULL,
  wrong      INT         NOT NULL,
  points     INT         NOT NULL,
  created_at BIGINT      NOT NULL,
  KEY idx_user_time (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
