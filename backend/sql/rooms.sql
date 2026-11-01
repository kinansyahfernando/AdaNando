-- Tabel untuk fitur Belajar Bareng (room).
-- Jalankan di database db_utbk (HeidiSQL / phpMyAdmin di Laragon),
-- atau cukup jalankan:  node scripts/create-room-tables.js
-- Waktu disimpan sebagai milidetik epoch (BIGINT) supaya tidak ada masalah zona waktu.

CREATE TABLE IF NOT EXISTS rooms (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  code             VARCHAR(8)  NOT NULL UNIQUE,
  host_id          INT         NOT NULL,
  subtest_id       VARCHAR(20) NOT NULL,
  question_ids     TEXT        NOT NULL,
  duration_seconds INT         NOT NULL,
  status           VARCHAR(10) NOT NULL DEFAULT 'waiting',
  started_at       BIGINT      NULL,
  created_at       BIGINT      NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS room_players (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  room_id      INT    NOT NULL,
  user_id      INT    NOT NULL,
  joined_at    BIGINT NOT NULL,
  score        INT    NOT NULL DEFAULT 0,
  correct      INT    NOT NULL DEFAULT 0,
  wrong        INT    NOT NULL DEFAULT 0,
  answers      TEXT   NULL,
  submitted_at BIGINT NULL,
  UNIQUE KEY uq_room_user (room_id, user_id),
  KEY idx_room (room_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
