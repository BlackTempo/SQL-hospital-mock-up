CREATE DATABASE IF NOT EXISTS sairaalan_tyovuorot
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE sairaalan_tyovuorot;

-- Luodaan tarvittavat taulut luodun ER-mallin mukaisesti

CREATE TABLE Ammattinimike (
  idAmmattinimike INT AUTO_INCREMENT PRIMARY KEY,
  nimi VARCHAR(60) NOT NULL,
  UNIQUE (nimi)
);

CREATE TABLE Tyontekija (
  idTyontekija INT AUTO_INCREMENT PRIMARY KEY,
  etunimi    VARCHAR(60) NOT NULL,
  sukunimi   VARCHAR(60) NOT NULL,
  puhelin    VARCHAR(30),
  sahkoposti VARCHAR(120),
  idAmmattinimike INT NOT NULL,
  lisatiedot VARCHAR(255),
  FOREIGN KEY (idAmmattinimike) REFERENCES Ammattinimike(idAmmattinimike)
);

CREATE TABLE Patevyys (
  idPatevyys INT AUTO_INCREMENT PRIMARY KEY,
  nimi VARCHAR(80) NOT NULL,
  UNIQUE (nimi)
);

CREATE TABLE TyontekijaPatevyys (
  idTyontekija INT NOT NULL,
  idPatevyys   INT NOT NULL,
  PRIMARY KEY (idTyontekija, idPatevyys),
  FOREIGN KEY (idTyontekija) REFERENCES Tyontekija(idTyontekija),
  FOREIGN KEY (idPatevyys)   REFERENCES Patevyys(idPatevyys)
);

CREATE TABLE Toimipiste (
  idToimipiste INT AUTO_INCREMENT PRIMARY KEY,
  nimi VARCHAR(80) NOT NULL,
  UNIQUE (nimi)
);

CREATE TABLE Vuorotyyppi (
  idVuorotyyppi INT AUTO_INCREMENT PRIMARY KEY,
  nimi      VARCHAR(40) NOT NULL,   -- Aamu / Ilta / Yö
  alkuaika  TIME NOT NULL,
  loppuaika TIME NOT NULL,
  UNIQUE (nimi)
);

CREATE TABLE Tehtava (
  idTehtava INT AUTO_INCREMENT PRIMARY KEY,
  paivamaara DATE NOT NULL,
  idVuorotyyppi INT NOT NULL,
  idToimipiste  INT NOT NULL,
  idAmmattinimike INT NOT NULL,
  tarvittava_maara INT NOT NULL CHECK (tarvittava_maara >= 1),
  lisatiedot VARCHAR(255),
  FOREIGN KEY (idVuorotyyppi) REFERENCES Vuorotyyppi(idVuorotyyppi),
  FOREIGN KEY (idToimipiste)  REFERENCES Toimipiste(idToimipiste),
  FOREIGN KEY (idAmmattinimike) REFERENCES Ammattinimike(idAmmattinimike),
  INDEX (paivamaara)
);

CREATE TABLE Kiinnitys (
  idKiinnitys INT AUTO_INCREMENT PRIMARY KEY,
  idTehtava    INT NOT NULL,
  idTyontekija INT NOT NULL,
  luontiaika   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (idTehtava) REFERENCES Tehtava(idTehtava),
  FOREIGN KEY (idTyontekija) REFERENCES Tyontekija(idTyontekija),
  UNIQUE (idTehtava, idTyontekija)  -- sama hlö tehtävään vain kerran
);

CREATE TABLE Kalenteri (
  paivamaara DATE PRIMARY KEY
);

-- näkymät alkaa tästä
-- Työntekijät suunnitelmat

CREATE VIEW v_tyontekijan_suunnitelma AS
SELECT k.idKiinnitys, ty.idTyontekija, ty.etunimi, ty.sukunimi, th.paivamaara, v.nimi AS vuoro, v.alkuaika, v.loppuaika, 
tp.nimi AS toimipiste,
am.nimi AS ammattinimike,
th.lisatiedot AS tehtavan_lisatiedot
FROM Kiinnitys AS k
INNER JOIN Tyontekija AS ty ON ty.idTyontekija = k.idTyontekija
INNER JOIN Tehtava AS th    ON th.idTehtava    = k.idTehtava
INNER JOIN Vuorotyyppi AS v ON v.idVuorotyyppi = th.idVuorotyyppi
INNER JOIN Toimipiste AS tp ON tp.idToimipiste = th.idToimipiste
INNER JOIN Ammattinimike AS am ON am.idAmmattinimike = th.idAmmattinimike;

-- Työvuorolista (kaikki tehtävät ja niihin kiinnitetyt, myös tyhjät tehtävät näkyvät)
CREATE VIEW v_tyovuorolista AS
SELECT th.idTehtava, th.paivamaara, v.nimi AS vuoro, tp.nimi AS toimipiste, am.nimi AS ammattinimike, th.tarvittava_maara, ty.idTyontekija,
  CONCAT(ty.etunimi," ",ty.sukunimi) AS tyontekija, ty.puhelin, ty.sahkoposti
FROM Tehtava AS th
INNER JOIN Vuorotyyppi AS v ON v.idVuorotyyppi = th.idVuorotyyppi
INNER JOIN Toimipiste AS tp ON tp.idToimipiste = th.idToimipiste
INNER JOIN Ammattinimike AS am ON am.idAmmattinimike = th.idAmmattinimike
LEFT JOIN Kiinnitys AS k ON k.idTehtava = th.idTehtava
LEFT JOIN Tyontekija AS ty ON ty.idTyontekija = k.idTyontekija;

-- Vapaalista (ne työntekijät, joilla EI ole kiinnitystä valittuna päivänä)
CREATE VIEW v_vapaalista AS
SELECT ka.paivamaara, ty.idTyontekija, ty.etunimi, ty.sukunimi, am.nimi AS ammattinimike, ty.puhelin, ty.sahkoposti
FROM Kalenteri AS ka
CROSS JOIN Tyontekija AS ty
INNER JOIN Ammattinimike AS am ON am.idAmmattinimike = ty.idAmmattinimike
LEFT JOIN (
  SELECT k.idTyontekija, th.paivamaara
  FROM Kiinnitys AS k
  JOIN Tehtava AS th ON th.idTehtava = k.idTehtava
  GROUP BY k.idTyontekija, th.paivamaara
) 
varatut ON varatut.idTyontekija = ty.idTyontekija AND varatut.paivamaara = ka.paivamaara
WHERE varatut.idTyontekija IS NULL;


-- Taulut tehty käsin ja samoin pohjat datan syötölle, mutta itse data (henkilötiedot, ammattinimikkeet yms.) on generoitu tekoälyn avulla. 
-- Datan lisäys, 10 riviä dataa lisätään, pl. vuorotyyppi


INSERT INTO Ammattinimike (nimi) VALUES
("Sairaanhoitaja"),("Yleislääkäri"),("Kirurgi"),
("Anestesialääkäri"),("Sairaala-apulainen"),
("Osastonhoitaja"),("Laboratoriohoitaja"),
("Röntgenhoitaja"),("Fysioterapeutti"),("Siistijä");

INSERT INTO Toimipiste (nimi) VALUES
("Leikkaussali 1"),("Leikkaussali 2"),("Päivystys"),
("Vuodeosasto A"),("Vuodeosasto B"),
("Poliklinikka"),("Laboratorio"),
("Röntgen"),("Fysioterapia"),("Siivous");

INSERT INTO Vuorotyyppi (nimi, alkuaika, loppuaika) VALUES
("Aamu","08:00:00","16:00:00"),
("Ilta","16:00:00","00:00:00"),
("Yö","00:00:00","08:00:00");

INSERT INTO Tyontekija (etunimi,sukunimi,puhelin,sahkoposti,idAmmattinimike,lisatiedot) VALUES
("Anna","Aalto","0401111111","anna.aalto@supernova.fi",1,"IVC-pätevyys"),
("Mikko","Meri","0401111112","mikko.meri@supernova.fi",1,""),
("Katri","Korpela","0401111113","katri.korpela@supernova.fi",1,"Leikkaussalikokemus"),
("Jussi","Järvi","0401111114","jussi.jarvi@supernova.fi",2,""),
("Laura","Laine","0401111115","laura.laine@supernova.fi",2,""),
("Kalle","Kallio","0401111116","kalle.kallio@supernova.fi",3,""),
("Sari","Salo","0401111117","sari.salo@supernova.fi",4,""),
("Oona","Oja","0401111118","oona.oja@supernova.fi",5,""),
("Pekka","Puro","0401111119","pekka.puro@supernova.fi",5,""),
("Veera","Vuori","0401111120","veera.vuori@supernova.fi",1,"Vastuuvuoroja");

/* Totesin lisäyksen jälkeen työntekijöitä olevan liian vähän, 
ja lisään enemmän, en anna uusille pätevyyksiä kuitenkaan. Täytettä dataan, generoitu tekoälyllä.
*/
INSERT INTO Tyontekija (etunimi,sukunimi,puhelin,sahkoposti,idAmmattinimike,lisatiedot) VALUES -- Mietin olisinko luonut fiksumman tavan sijoittaa data, menin kuitenkin tällä
("Markus","Mäki","0401111121","markus.maki@supernova.fi",6,"Osastonhoitaja, 10v kokemus"),
("Heli","Heinonen","0401111122","heli.heinonen@supernova.fi",7,"Laboratoriopäällikkö"),
("Antti","Ahonen","0401111123","antti.ahonen@supernova.fi",7,"Verinäytteet"),
("Riikka","Ranta","0401111124","riikka.ranta@supernova.fi",8,"Röntgentutkija"),
("Petri","Pajunen","0401111125","petri.pajunen@supernova.fi",8,"TT-kuvauskokemus"),
("Eeva","Eskelinen","0401111126","eeva.eskelinen@supernova.fi",9,"Urheilufysioterapeutti"),
("Tuomas","Tervo","0401111127","tuomas.tervo@supernova.fi",9,"Kuntoutus"),
("Jenna","Jokinen","0401111128","jenna.jokinen@supernova.fi",10,"Siivouspalvelu, infektiosuoja"),
("Ville","Virtanen","0401111129","ville.virtanen@supernova.fi",1,"Sairaanhoitaja, ensiapu"),
("Sanna","Saari","0401111130","sanna.saari@supernova.fi",2,"Yleislääkäri, työterveys");

INSERT INTO Patevyys (nimi) VALUES
("IVC"),("Leikkaussali"),("Triagenäyte"),("Anestesia"),
("Kirurgia"),("Tartuntasuojelu"),("Röntgen"),
("Laboratoriotyö"),("Fysioterapia"),("Siivous");

INSERT INTO TyontekijaPatevyys (idTyontekija,idPatevyys) VALUES -- Ei fiksuin tapa tehdä visuaalisesti, mutta ihan ok kun oli toisessa ikkunassa SELECT * FROM Tyontekija; ja SELECT * FROM Patevyys;
(1,1),(1,6),
(2,6),
(3,2),(3,6),
(4,5),
(5,5),
(6,5),
(7,4),
(8,10),
(9,10),
(10,2);

INSERT INTO TyontekijaPatevyys (idTyontekija,idPatevyys) VALUES
-- Markus Mäki, osastonhoitaja (yleisosaaminen)
(11,6),

-- Heli Heinonen, laboratoriohoitaja
(12,8),(12,6),

-- Antti Ahonen, laboratoriohoitaja
(13,8),

-- Riikka Ranta, röntgenhoitaja
(14,7),(14,6),

-- Petri Pajunen, röntgenhoitaja
(15,7),

-- Eeva Eskelinen, fysioterapeutti
(16,9),

-- Tuomas Tervo, fysioterapeutti
(17,9),

-- Jenna Jokinen, siistijä
(18,10),(18,6),

-- Ville Virtanen, sairaanhoitaja
(19,1),(19,3),

-- Sanna Saari, yleislääkäri
(20,5);

-- Kalenteri, lisätään 2vk ajalle tästä päivästä (koodin tekopäivästä), kokeillaan tehdä koneen kellosta 2vk eteenpäin generoidusti vaihtamalla erotin. ps. Tein aika pitkään tätä... mutta onnistuin!
-- Lisätään tänään + seuraavat 13 päivää (yht. 14 pv)
DELIMITER //
CREATE PROCEDURE tayta_kalenteri(IN paivia INT)
BEGIN
  DECLARE d DATE;
  SET d = CURDATE();
  WHILE paivia > 0 DO
    INSERT INTO Kalenteri(paivamaara) VALUES (d);
    SET d = DATE_ADD(d, INTERVAL 1 DAY);
    SET paivia = paivia - 1;
  END WHILE;
END//
DELIMITER ;

-- Kokeillaan kutsua juuri tehtyä proseduuria
CALL tayta_kalenteri(14);

-- Tehtävä, eri paikat/ajankohdat/nimikkeet
INSERT INTO Tehtava (paivamaara,idVuorotyyppi,idToimipiste,idAmmattinimike,tarvittava_maara,lisatiedot) VALUES
("2025-09-12",1,1,3,1,"Kirurgi leikkuri 1 aamuvuoro"),
("2025-09-12",1,1,4,1,"Anestesia leikkuri 1"),
("2025-09-12",1,1,1,2,"2 hoitajaa leikkuri 1"),
("2025-09-12",1,3,2,1,"Päivystyksen yleislääkäri"),
("2025-09-12",1,3,1,2,"Päivystyksen hoitajat"),
("2025-09-12",1,2,3,1,"Kirurgi leikkuri 2 aamuvuoro"),
("2025-09-12",1,2,4,1,"Anestesia leikkuri 2"),
("2025-09-12",1,2,1,2,"2 hoitajaa leikkuri 2"),
("2025-09-12",2,4,1,1,"Vuodeosasto A iltavuoro"),
("2025-09-12",3,5,1,1,"Vuodeosasto B yövuoro"),
("2025-09-12",1,3,2,1,"Päivystyksen yleislääkäri aamu"),
("2025-09-13",1,1,3,1,"Kirurgi leikkuri 1 aamuvuoro"),
("2025-09-13",1,1,4,1,"Anestesia leikkuri 1"),
("2025-09-13",1,1,1,2,"2 hoitajaa leikkuri 1"),
("2025-09-13",1,3,2,1,"Päivystyksen yleislääkäri"),
("2025-09-13",1,3,1,2,"Päivystyksen hoitajat"),
("2025-09-13",1,2,3,1,"Kirurgi leikkuri 2 aamuvuoro"),
("2025-09-13",1,2,4,1,"Anestesia leikkuri 2"),
("2025-09-13",1,2,1,2,"2 hoitajaa leikkuri 2"),
("2025-09-13",2,4,1,1,"Vuodeosasto A iltavuoro"),
("2025-09-13",3,5,1,1,"Vuodeosasto B yövuoro"),
("2025-09-13",1,3,2,1,"Päivystyksen yleislääkäri aamu"),
("2025-09-14",1,1,3,1,"Kirurgi leikkuri 1 aamuvuoro"),
("2025-09-14",1,1,4,1,"Anestesia leikkuri 1"),
("2025-09-14",1,1,1,2,"2 hoitajaa leikkuri 1"),
("2025-09-14",1,3,2,1,"Päivystyksen yleislääkäri"),
("2025-09-14",1,3,1,2,"Päivystyksen hoitajat"),
("2025-09-14",1,2,3,1,"Kirurgi leikkuri 2 aamuvuoro"),
("2025-09-14",1,2,4,1,"Anestesia leikkuri 2"),
("2025-09-14",1,2,1,2,"2 hoitajaa leikkuri 2"),
("2025-09-14",2,4,1,1,"Vuodeosasto A iltavuoro"),
("2025-09-14",3,5,1,1,"Vuodeosasto B yövuoro"),
("2025-09-14",1,3,2,1,"Päivystyksen yleislääkäri aamu");

-- Kiinnitys, täytetään osa tarpeista
INSERT INTO Kiinnitys (idTehtava,idTyontekija) VALUES
(1,6),   -- Kirurgi: Kalle Kallio
(2,7),   -- Anestesia: Sari Salo
(3,1),   -- Hoitaja: Anna Aalto
(3,3),   -- Hoitaja: Katri Korpela
(4,4),   -- Yleislääkäri: Jussi Järvi
(5,2),   -- Hoitaja: Mikko Meri
(6,6),   -- Kirurgi
(7,7),   -- Anestesia
(8,10),  -- Hoitaja
(9,8),   -- Sairaala-apulainen (jos haluat hoitajan, muuta tehtävän nimike)
(10,2),  -- Yövuoro hoitaja, kavereiden kesken yökkö
(11,5);  -- Päivystyksen yleislääkäri


-- Lisätään lisää työvuoroja ja kiinnitetään...

INSERT INTO Kiinnitys (idTehtava,idTyontekija) VALUES
(12,6),
(13,7),
(14,1),
(15,3),
(16,4),
(17,2),
(18,6),
(19,7),
(20,10),
(21,8),
(22,2),
(23,5);

-- Viewien käyttö

SELECT * FROM v_tyontekijan_suunnitelma
WHERE idTyontekija = 6 -- Kalle Kallio
  AND paivamaara BETWEEN "2025-09-08" AND "2025-09-15"
ORDER BY paivamaara, alkuaika;

SELECT * FROM v_tyovuorolista -- Yleinen työvuorolista
WHERE paivamaara BETWEEN "2025-09-08" AND "2025-09-15"
ORDER BY paivamaara, vuoro, toimipiste, ammattinimike, tyontekija;

SELECT * FROM v_vapaalista -- Vapaalla olevat
WHERE paivamaara BETWEEN "2025-09-08" AND "2025-09-15"
ORDER BY paivamaara, sukunimi, etunimi;
