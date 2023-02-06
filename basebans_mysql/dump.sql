-- phpMyAdmin SQL Dump
-- version 5.1.3
-- https://www.phpmyadmin.net/
--
-- Хост: localhost
-- Время создания: Ноя 17 2022 г., 12:39
-- Версия сервера: 10.5.18-MariaDB-1:10.5.18+maria~deb11
-- Версия PHP: 7.3.33

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

-- --------------------------------------------------------

--
-- Структура таблицы `mb_bans`
--

CREATE TABLE `mb_bans` (
  `name` tinyblob NOT NULL,
  `ip` varchar(16) NOT NULL,
  `steamid` varchar(32) NOT NULL,
  `date` int(11) NOT NULL,
  `time` int(11) NOT NULL,
  `reason` varchar(255) NOT NULL,
  `admin` tinyblob NOT NULL,
  `immunity` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

--
-- Индексы сохранённых таблиц
--

--
-- Индексы таблицы `mb_bans`
--
ALTER TABLE `mb_bans`
  ADD PRIMARY KEY (`steamid`),
  ADD KEY `ip` (`ip`),
  ADD KEY `time` (`time`),
  ADD KEY `date` (`date`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
