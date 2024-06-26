; ***********************************************************************
; *                                                                     *
; *                   Резидентный монитор одноплатной                   *
; *                          учебной МикроЭВМ                           *
; *                             УМПК-80/ВМ                              *
; *                                                                     *
; * Из книги "МикроЭВМ: В 8 кн.: Практ. пособие/Под ред.                *
; *           М59 Л. Н. Преснухина.                                     *
; *           Кн. 7. Учебные стенды / Ю. И. Волков,   В. Л. Горбунов,   *
; *                                   Д. И. Панфилов, С. Г. Шаронин.    *
; *           — М.: Высш. шк., 1988. - 224 с.: ил. ISBN 5-06-001350-2"  *
; *           Приложение 1. стр 141                                     *
; *                                                                     *
; * Перепечатали: В. Ю. Кадырин. @GalaxyShad. 2024                      *
; *               email:    vadim.kadyrin@mail.ru                       *
; *               telegram: @GalaxyShad                                 *
; *               github:   https://github.com/GalaxyShad               *
; *                                                                     *
; *               К. А. Романова. @KupavaRomanova. 2024                 *
; *               https://github.com/KupavaRomanova                     *
; *                                                                     *
; * Файл может быть транслирован с помощью:                             *
; * https://github.com/GalaxyShad/Some-i8080-ASM-Translator             *
; *                                                                     *
; ***********************************************************************

; 
; Адреса УВВ модуля
; 
OTR     EQU     4       ; Регистр вывода на магнитафон, звук
ITR     EQU     4       ; Регистр ввода с магнитафона
LOUT    EQU     5       ; Выходной регистр
KEY     EQU     6       ; Регистр чтения клавиатуры
DSP     EQU     6       ; Регистр сегментов дисплея
SCAN    EQU     7       ; Регистр сканирования
CTL     EQU     8       ; Регистр управления (Базовый адрес)

;
; Назначение констант
;
PC      EQU     0800h   ; Начальное значение PC пользователя
TIME    EQU     67h     ; Константа цикла задержки в 1 МС
FREQ    EQU     20h     ; Константа частоты BEEP
DUR     EQU     40h     ; Константа длительности BEEP

RS4C    EQU     0AF6h   ; Точка выхода по RST 4
RS5C    EQU     0AF9h   ; Точка выхода по RST 5
RS6C    EQU     0AFCh   ; Точка выхода по RST 6

TPR     EQU     0AFFh   ; Верх защищенного ОЗУ
UR      EQU     0AEFh   ; Верх ОЗУ (Без точек входа по RST)
ERAM    EQU     0Ch     ; Конец ОЗУ

LMC     EQU     06A0h   ; Стартовая мелодия

;
; Области стека монитора и пользователя в ОЗУ
;
ORG 0BB0h               
USP:    DS 0            ; Начальное значение SP пользователя
        DS 1Eh
        
MSP:    DS 0            ; Начальное значение SP монитора

;
; Область переменных монитора в ОЗУ
;
ORG 0BD1h
TSAVS:  DS 2            ; Временная область сохранения SP
TSAVH:  DS 2            ; Временная область сохранения PC
RAML1:  DS 1            ; Временная область программы JMP USER
RS:     DS 1            ; Адрес состояния ОЗУ
RAML2:  DS 4            ; Область программы JMP USER

SAVRG:  DS 1            ; Область сохранения регистров
SAVPC:  DS 2            ; Область сохранения PC
SAVSL:  DS 1            ; Область сохранения SPL
SAVSH:  DS 1            ; Область сохранения SPH
SAVL:   DS 2            ; Область сохранения L и H
SAVE:   DS 2            ; Область сохранения E и D
SAVC:   DS 2            ; Область сохранения C и B
SAVPW:  DS 1            ; Область сохранения флагов
SAVA:   DS 1            ; Область сохранения A
UDKY:   DS 8            ; Область хранения образа клавиатуры
UDSP:   DS 6            ; Область недекодированных сообщений дисплея
UDSP6:  DS 2            ; Флаг включения десятичной точки
RMP:    DS 2            ; Указатель сообщения о текущем РГ
DDSP:   DS 6            ; Область декодированных сообщений дисплея

ORG 0000h
; 
; RST 0 - точка входа в монитор по сбросу
; ( Клавиша "R" или включение питания )
;
RESET:
    MVI H, 008h     ; Адрес начала ОЗУ
    XRA A
    CMA
    MOV M, A        ; Запись FF в одну из ячеек ОЗУ
    JMP STRT

; 
; RST 1 - точка входа в монитор по прерыванию 
; ( Клавиша "СТ" или точка останова )
;
RS1:
    SHLD TSAVH      ; Сохранение HL пользователя
    OUT 008h        ; Разрешение записи в ОЗУ
    JMP TRP

;
; RST 2 - свисток с фиксированной длительносью и тоном
;
BEEP:
    MVI B, FREQ     ; Частота сигнала
    MVI D, DUR      ; Длительность сигнала 
    JMP BEEP2
    NOP

; 
; RST 3 - перемещение сообщения по адресу DE в область UDSP
; 
STDM:
    PUSH B          
    LXI H, UDSP     ; Первый символ в UDSP
    JMP SDM 
    NOP 

RS4:
    JMP RS4C        ; Переход на П/П пользователя
    DB 0, 0, 0
    DB 0, 0

RS5:
    JMP RS5C        ; Переход на П/П пользователя
    DB 0, 0, 0
    DB 0, 0

RS6:
    JMP RS6C        ; Переход на П/П пользователя
    DB 0, 0, 0
    DB 0, 0

RS7:
    RST 2           ; Свисток
    JMP STRT6       ; Возврат в монитор
    DB 0, 0, 0
    DB 0

; 
; Тест самопроверки и начальная 
; 
STRT:
    CMP M           ; Защита памяти снята?
    JNZ PPER        ; - Если нет (попали на RST 0 из-за ошибки стека пользователя)
    LXI SP, MSP     ; Инициализация стека монитора
    XRA A
    MOV H, A
    MOV L, A
    OUT LOUT

; 
; Тест ПЗУ модуля
; 
STRT1:
    ADD M           ; Вычисление контрольной суммы ПЗУ
    INX H 
    MOV C, A 
    MVI A, 8H       ; ПЗУ кончилось?
    CMP H
    MOV A, C 
    JNZ STRT1       ; - нет, продолжение цикла
    DCX H           ; HL - на значение контрольной суммы
    SUB M
    CMP M
    MVI E, 07CH     ; Сообщим об ошибке
    DB 0, 0, 0      ; JNZ MERR1 - переход на ее индикацию

    ;
    ; Тест ОЗУ модуля
    ;
    XRA A               ; Очистим А 
    LXI H, PC           ; HL на начало ОЗУ 
    MVI B, 3            ; Постоянное слагаемое 
STRT2:
    MOV M, A            ; Запомним в памяти 
    ADD B               ; Увеличим А на 3
    INX H               ; На следующий адрес ОЗУ 
    MOV C, A
    MOV A, H 
    CPI ERAM            ; ОЗУ кончилось? 
    MOV A, C 
    JNZ STRT2           ; - нет, продолжим запись 
    XRA A 
    LXI H, PC           ; HL на начало памяти 
STRT3:
    CMP M               ; Данные записались правильно?
    JNZ MERR            ; - если была ошибка 
    CMA 
    MOV M, A            ; Запишем инвертированный байт 
    CMP M               ; Он записался правильно? 
    JNZ MERR            ; - была ошибка 
    CMA                 ; Начальное значение А 
    ADD B 
    INX H               ; Следующий адрес памяти 
    MOV C, A 
    MOV A, H 
    CPI ERAM            ; Дошли до конца ОЗУ?
    MOV A, C 
    JNZ STRT3           ; Нет - продолжим проверку
    ;
    ; Тест дисплей модуля
    ;
    MVI B, 080H         ; Счетчик цикла 
STRT4:
    LXI D, ALL          ; Сообщение "Все сегменты" 
    RST 3               ; Скопируем его в область дисплея
    CALL DCD            ; И отобразим
    DCR B               ; Цикл кончился?
    JNZ STRT4           ; Нет, продолжаем 
    ;
    ; Очистка памяти (Заполнение нулями)
    ;
    MVI B, 0
    MVI A, ERAM         ; Старший байт адреса верхушки ОЗУ 
    LXI H, PC           ; HL - на начало ОЗУ 
STRT5:
    MOV M, B            ; Очистим ячейку памяти 
    INX H               
    CMP H               
    JNZ STRT5           ; Пока не дойдем до верхушки ОЗУ 
    MVI A, 0FFH         
    OUT LOUT            ; Включим светодиоды верхнего РГ 
    CALL LMC            ; Сыграем музыку 
    XRA A 
    OUT LOUT            ; Выключим светодиоды (Очистим LOUT)
    ;
    ; Инициализация переменных монитора
    ;
STRT6:
    LXI H, USP          ; Стек пользователя
    SHLD SAVSL          
    LXI H, RS           ; Адрес состояния 
    MVI M, 0            ; Установим состояние "Монитор"
    LXI H, PC           ; Начало ОЗУ 
    SHLD SAVPC          ; Начало программы пользователя 
                        ; По умолчанию 
    MVI A, 0FFH         ; Код RST7
    STA TPR             ; Запомним его ОЗУ 
    STA UR              
    JMP TRP3            ; Перейдем на монитор 

;
; Обработка ошибок стека 
;
PPER:
    LXI SP, MSP         ; Стек монитора 
    LXI H, PC           ; Счетчик команд по умолчанию 
    SHLD SAVPC          ; Запомним его 
    RST 2               ; Сигнал ошибки 
    XRA A               
    STA RS              ; Состояние "Монитор"
    LXI D, PPM          ; Указать на ошибку работы со стеком 
    JMP TRP4 

;
; Индикация ошибок ЗУ
;
MERR:
    MVI E, 87H          ; Адрес сообщения об ошибке ОЗУ 
    MVI D, 2 
    RST 3               ; Переместим его в области дисплея 
    LXI H, UDSP+5 
    MVI M, 10H 
MERR2: 
    RST 2               ; Будем свистеть 
    MVI B, 70H 
MERR3:
    CALL DCD            ; И выводить сообщение 
    DCR B 
    JNZ MERR3 
    JMP MERR2 

; 
; RST 1 - Главная точка входа в монитор
; 
TRP:
    LXI H, 0            ; Извлекаем SP пользователя,
    JNC TRP1            ; Сохранив его флаг CY 
    DCX H 
TRP1: 
    DAD SP 
    JNC TRP2 
    INX H 
TRP2:
    SHLD TSAVS          ; Сохраним SP пользователя 
    LXI SP, TSAVS       ; Адрес области сохранения PSW 
    PUSH PSW 
    LXI H, RS           ; Адрес признака состояния 
    XRA A 
    CMP M               ; Состояние "Монитор"
    STA UDSP6           ; Очищаем признак модификации данных 
    JNZ TRP6            ; - если пришли из программы пользов.
TRP3:
    LXI D, DMT          ; Сообщение "Начало" 
    EI 
TRP4:
    XRA A 
    OUT LOUT            ; Очистим выходной регистр 
    OUT CTL             ; Снимем защиту ОЗУ 
    RST 3               ; Сообщение - в область дисплея 
TRP5: 
    CALL KIND           ; Введем клавишу 
    CALL CFETA          ; Определение жоступных клавиш 
    JMP TRP5            
TRP6:
    MOV M, A            ; Установим состояние "Монитор" 

    ;
    ; Сохранение регистров пользователя
    ;
    POP PSW 
    POP H                   ; Записать текущее значение SP в HL 
    INX H 
    INX H 
    SHLD SAVSL              ; Сохранить его в ОЗУ 
    DCX H 
    DCX H 
    SPHL                    ; Восстановить SP пользователя 
    POP H                   ; Адрес возврата к программе пользов. 
    SHLD SAVPC              ; Сохраним его в ОЗУ 
    LXI SP, 0BE8H           ; Адрес сохранения регистров 
    LHLD TSAVH              ; Восстановить HL 
    PUSH PSW                ; Сохраним регистры пользователя 
    PUSH B 
    PUSH D 
    PUSH H 
    EI 
    NOP 
    NOP 
    NOP  
TRP7:
    LXI SP, SAVPC 
    POP B 
    LXI SP, MSP             ; Восстановить SP монитора 
    JMP FETA3

; 
; Ввод и опредение кода нажатой клавиши
; 
KIND:
    PUSH D 
    PUSH H 
KIND1: 
    CALL DCD            ; Выдать сообщение на дисплей 
    CALL KPU            ; Клавиша нажата? 
    JNZ KIND1           ; Да, подождем пока не отпустят 
KIND2: 
    CALL DCD            ; Выдать сообщение на дисплей 
    CALL KPU            
    JZ KIND2            ; Если нет нажатой клавиши - ждать 
    LXI H, UDKY         ; Адрес образа 0 строки клавиатуры 
    MVI D, 0FFH         ; Счетчик строк = -1
KIND3:
    MOV A, M            ; Получим образ текущей строки 
    CPI 0F7H            ; Клавиша "Шаг машинного цикла"?
    JZ KIND5            ; Да, перейдем 
    CMA                 
    INR L               ; Следующая строка 
    INR D               ; Следующий блок таблицы соответствия 
    ANA A               ; Есть клавиша в этой строке?
    JZ KIND3            ; Нет, перейдем на следующую 
    CPI 4               
    JNZ KIND4           
    DCR A               ; Установим А = 3, если было А = 4
KIND4:
    ADD D               ; Прибавим три раза номер строки для 
    ADD D               ; Получения смещения в таблице 
    ADD D               
    MOV E, A            ; Запомним индекс табл. соответствия 
    MVI D, 0            
    LXI H, KIT - 1      ; Начальный адрес таблицы соотв 
    DAD D               ; Адрес кода нажатой клавиши 
    MOV A, M            ; Получим ее код 
KIND5:
    POP H               
    POP D               
    RET                 

; 
; Определение факта нажатия какой-либо клавиши
; 
KPU:
    PUSH B 
    CALL KRD            ; Считаем клавиатуру
    MVI B, 8            ; Число строк клавиатуры 
    LXI H, UDKY         ;Область записи образа клавиатуры 
    MVI A, 0FFH         
KPU1:
    ANA M               ; Есть ли нажатая клавиша?
    INR L 
    DCR B 
    JNZ KPU1            ; Проверяем все строки клавиатуры 
    CPI 0FFH            ; Признак Z = 0, если нет нажатых клавиш 
    POP B 
    RET 

; 
; Чтение клавиатуры и запоминание её образа в ОЗУ (UDKY)
; 
KRD:
    LXI H, UDKY         ; Область записи образа клавиатуры 
    XRA A 
    OUT DSP             ; Очистим дисплей 
    CMA 
    DCR A               ; 11111110 В - указатель сканирования 
    STC 
KRD1:
    OUT SCAN            ; Выберем одну строку 
    MOV B, A 
    IN KEY              ; Вводим выбранную строку 
    MOV M, A 
    MOV A, B 
    INR L               ; Адрес следующей строки 
    RAL                 ; Указатель - на следующую строку 
    JC KRD1             ; Повторим если не кончили 
    RET 

; 
; Таблица определения кодов клавиш
;  
KIT: 
    DB 86H              ; Шаг команды
    DB 85H              ; Программный счетчик 
    DB 0                ; Не используется 
    DB 84H              ; Пуск 
    DB 80H              ; Отыскание регистра 
    DB 82H              ; Отыскание адреса 
    DB 0                ; 0
    DB 83H              ; Записать / Увеличить  
    DB 81H              ; Уменьшить 
    DB 1                ; 1
    DB 2                ; 2
    DB 3                ; 3
    DB 4                ; 4
    DB 5                ; 5 
    DB 6                ; 6
    DB 7                ; 7
    DB 8                ; 8
    DB 9                ; 9
    DB 0AH              ; A 
    DB 0BH              ; B 
    DB 0CH              ; C 
    DB 0DH              ; D 
    DB 0EH              ; E
    DB 0FH              ; F 

; 
; Сканирование дисплея (один раз)
; 
SDS:
    PUSH PSW 
    PUSH H 
    PUSH B 
    LXI H, DDSP+5       ; Адрес последнего символа 
    MVI B, 20H          ; Указатель - на пятый символ 
SDS1:
    XRA A 
    OUT SCAN            ; Погасим дисплей 
    MOV A, M            ; Код отображаемого символа 
    OUT DSP             ; Записываем в регистр сегментов 
    MOV A, B 
    OUT SCAN            ; И включаем нужный индикатор 
    CALL DELA           ; ЗАДЕРЖКА 1 МС 
    DCR L               ; Адрес кода следующего символа 
    RAR                 ; Указатель - на следующий символ 
    MOV B, A 
    JNC SDS1            ; Отображаем 6 символов 
    XRA A 
    OUT DSP             ; Гасим дисплей 
    POP B 
    POP H 
    POP PSW 
    RET 

; 
; Декодирование выводимого символа 
; 
DCD:
    PUSH PSW 
    PUSH B 
    PUSH D 
    PUSH H 
    LXI B, DDSP         ; Область декодированных символов 
    LXI D, UDSP         ; Область недекодированных символов 
DCD1:
    LXI H, DCC          ; Таблица декодирования символов 
    LDAX D              ; По смещению в таблице получим код 
    PUSH D 
    MOV E, A 
    MVI D, 0 
    DAD D 
    MOV A, M 
    STAX B              ; Запомним его 
    POP D 
    INR E 
    INR C 
    JNZ DCD1            ; Не последний символ - перейдем 
    LXI H, DDSP         ; Первый декодированный символ 
    LDAX D              ; Адрес признака модификации данных 
    ANA A 
    JZ DCD2 
    MOV A, M
    ORI 080H            ; Если признак установлен - поставим 
    MOV M, A            ; Запятую в позиции первого символа 
DCD2:
    POP H 
    POP D 
    POP B 
    POP PSW 
    CALL SDS            ; Отобразим сообщение 
    RET 

;
; Таблица декодирования отображаемых символов
;
DCC:
    DB 3FH          ; 0
    DB 6H           ; 1
    DB 5BH          ; 2
    DB 4FH          ; 3
    DB 66H          ; 4
    DB 6DH          ; 5
    DB 7DH          ; 6
    DB 7H           ; 7 
    DB 7FH          ; 8
    DB 6FH          ; 9
    DB 77H          ; A
    DB 7CH          ; B
    DB 39H          ; C
    DB 5EH          ; D
    DB 79H          ; E
    DB 71H          ; F
    DB 0            ; Пробел
    DB 76H          ; H
    DB 38H          ; L
    DB 6EH          ; Y
    DB 73H          ; Р
    DB 54H          ; Л
    DB 5CH          ; О
    DB 8            ; _
    DB 37H          ; П
    DB 40H          ; -
    DB 0FFH         ; Все сегменты
    DB 50H          ; R
    DB 30H          ; 1 левая

; 
; Копирование отображаемого сообщения по DE в UDSP ОЗУ
; 
SDM:
    MVI B, 6        ; Копируем 6 символов 
SDM1:
    LDAX D          ; Копируем символ 
    MOV M, A        ; Запомним его в UDSPX 
    INR L           ; Следующая ячейка UDSP 
    INX D           ; Следующий символ 
    DCR B           ; Все символы? 
    JNZ SDM1        ; Нет, повторим 
    POP B 
    RET 

; 
; Таблица сообщений
; 
DMT:    DB 16H, 15H, 0AH, 04H, 0AH, 11H     ; "НАЧАЛО"
FETCH:  DB 10H, 10H, 17H, 17H, 17H, 17H     ; "____  "
MA:     DB 0AH, 10H, 10H, 10H               ; "   A  " 
FLG:    DB 12H, 0FH, 10H, 10H               ; "  FL  "
MB:     DB 0BH, 10H, 10H, 10H               ; "   B  "
MC:     DB 0CH, 10H, 10H, 10H               ; "   C  "
MD:     DB 0DH, 10H, 10H, 10H               ; "   D  "
ME:     DB 0EH, 10H, 10H, 10H               ; "   E  "
MH:     DB 11H, 10H, 10H, 10H               ; "   H  "
ML:     DB 12H, 10H, 10H, 10H               ; "   L  "
SPH:    DB 11H, 14H, 05H, 10h               ; " SPH  "
SPL:    DB 12H, 14H, 05H, 10h               ; " SPL  "
PCH:    DB 11H, 0CH, 14H, 10h               ; " PCH  "
PCL:    DB 12H, 0CH, 14H                    ; " PCL  "
ROM:    DB 10H, 10H, 13H, 03H, 18H          ; " ПЗУ  "
ALL:    DB 1AH, 1AH, 1AH, 1AH, 1AH, 1AH     ; Все сегменты
RAM:    DB 10H, 10H, 13H, 03H, 0, 10h       ; " ОЗУ  "
PPM:    DB 1BH, 0EH, 14H, 05H               ; " SPER "
BLNKM:  DB 10H, 10H, 10H, 10H, 10H, 10H     ; "      "

; 
; Очистка дисплея
; 
    LXI D, BLNKM            ; Сообщение "  "
    RST 3                   ; Загрузим его
    CALL DCD                ; Выведем на дисплей                              
    RET

; 
; Таблица переходов по управляющим клавишам
; 
CHDSS:
    CPI 0F7H        ; Шаг машинного цикла
    JZ HDSS
CINSS:
    CPI 086H        ; Шаг команды
    JZ INSS
CRUN:
    CPI 84H         ; Пуск
    JZ RUN
CSTRM:
    CPI 083H        ; Увеличить и записать (Память)
    JZ STRM
CDCRM:
    CPI 81H         ; Уменьшить (Память)
    JZ DCRM
CFETA:
    CPI 82H         ; Отыскать адрес
    JZ FETA
CFETB:
    CPI 85H         ; Программный счетчик
    JZ TRP7
CFETR:
    CPI 80H         ; Отыскать регистр
    JZ FETR
    RET
CSTRR:
    CPI 83H         ; Записать и увеличить (Регистр)
    JZ STRR
CDCRR:
    CPI 81H         ; Уменьшить (Регистр)
    JZ DCRR
    JMP CFETA

; 
; Отыскание регистра
; 
FETR:
    POP H               ; Освободить стек
    LXI H, MA           ; Сообщение "  А  "
    LXI B, SAVA         ; Область сохранения регистра А
FETR1:
    DCX H               ; Адрес для записи данных на дисплей
    DCX H               
FETR2:
    SHLD RMP            ; Сохраним указатель сообщения
    XCHG                
    RST 3               ; Записать сообщение на дисплей
    LDAX B              ; Получить сохраненное значение А
    MOV E, A            ; Разделить его на полубайты
    LXI H, UDSP +1      
    CALL FETA7          
    DS 6
FETR3:
    CALL KIND           ; Введем клавишу
    CALL CSTRR          ; Управляющая клавиша?
    JNC FETR3           ; Если не управляющая и не цифра
    MOV E, A            
    INR L               ; HL - HA UDSP1
    MVI M, 000H         ; Запишем в него 0
FETR4:
    DCR L               ; Назад на UDSP0
    MOV M, E            ; Запомним там введенную цифру
FETR5:
    CALL DPS            ; Установим указатель ввода - точку
                        ; в младшем знаке дисплея введем
                        ; следующую клавишу 
    CALL CSTRR          ; Управляющая клавиша?
    JNC FETR5           ; Если не управляющая и не цифра
    INR L               ; Сдвинем данные на дисплее влево
    MOV D, E            
    MOV E, A            ; И
    MOV M, D            
    JMP FETR4           ; Продолжим....
    DS 9
; 
; Остановка десятичной точки
; 
DPS:
    MVI A, 1        ; Флаг включения десятичной точки
    STA UDSP6       ; Установим его
    CALL KIND       ; Введем следующую клавишу
    PUSH PSW 
    XRA A           ; Сбросим флаг
    STA UDSP6
    POP PSW
    RET

; 
; Отыскание адреса
; 
FETA:
    POP D               ; Освободить стек
FETAR:                  
    LXI D, FETCH        ; Адрес сообщения "____"
    RST 3               ; Скопируем
    MVI C, 4            ; Нужно ввести 4 цифры адреса
FETA1:
    CALL KIND           ; Введем клавишу 
    CALL CFETA          ; Управляющая?
    JNC FETA1
    LXI H, UDSP6
    MOV B, A            ; Сдвигаем адрес на дисплее влево
    CPI 1
    JNZ FETA8
    MVI A, 4
    CMP C 
    JNZ FETA8
    JMP FETAR
FETA8:
    MOV A, B  
    MVI B, 4
FETA2:
    DCR L 
    DCR L
    MOV D, M 
    INR L 
    MOV M, D 
    DCR B
    JNZ FETA2
    MOV M, A            ; Последняя цифра - младший знак 
    DCR C               ; Контроль на ввод всех цифр 
    JNZ FETA1
    CALL FETA6          ; Упакуем полученный адрес в BC
    MOV C, A
    INR L 
    CALL FETA6
    MOV B, A 
FETA3:
    LXI H, UDSP +5      ; Распакуем адрес из BC и запишем
    MOV E, B
    CALL FETA7
    DCR L 
    MOV E, C 
    CALL FETA7 
    DCR L
    LDAX B              ; Получим данные из указанного адреса
    MOV E, A            ; Распакуем их и запишем на дисплей 
    CALL FETA7

; 
; Изменение данных
;   
    CALL KIND           ; Вывели сообщение и ждем ввода
    CALL CHDSS          ; Не вернемся, если она управляющая 
    MOV E, A            ; Давнные запишем в E 
    MOV M, A            ; И в UDSP0
    INR L               
    MVI M, 0            ; В UDSP1 запишем 0
FETA4:
    DCR L               
    MOV M, E            ; Введенную цифру - в UDSP0
FETA5:
    CALL DPS            ; Включаем точку и вводим клавишу 
    CALL CSTRM          ; Управляющая?
    JNC FETA5           
    INR L               ; Сдвигаем данные на дисплее
    MOV D, E            
    MOV E, A            
    MOV M, D            
    JMP FETA4           ; Продолжаем ввод 

; 
; Упаковка двух шестнадцатиричных чисел в регистре А 
; 
FETA6:
    MOV E, M        ; Младшая шестнадцатиричная цифра
    INX H 
    MOV A, M        ; Старшая
    RLC
    RLC
    RLC
    RLC
    ORA E           ; Упакуем в регистре А 
    RET 

; 
; Распаковка шестнадцатиричного числа из регистра Е 
; 
FETA7:
    MOV A, E        ; Выделяем младшую цифру
    RRC
    RRC
    RRC
    RRC
    MVI D, 0FH 
    ANA D 
    MOV M, A        ; Записали
    DCR L 
    MOV A, E        ; Выделяем старшую цифру 
    ANA D 
    MOV M, A        ; Записали 
    RET 

; 
; Уменьшение адреса памяти  
; 
DCRM:
    DCX B           ; Уменьшить адрес 
    POP H 
    JMP FETA3       ; Отобразить его с содержимым 

; 
; Запись данных в память и увеличение адреса  
; 
STRM:
    POP D           ; Освободить стек 
    CALL FETA6      ; Упакуем данные с дисплея 
    MOV E, A        
    STAX B          ; Запишем и 
    LDAX B          ; Проверим как записалось 
    CMP E           
    INX B           ; Укажем на следующий адрес 
    JZ FETA3        ; Нормально - отобразим следующий 
    DCX B           ; Если нет - восстановим адрес,
    PUSH B          
    RST 2           ; попищим и 
    POP B           
    JMP FETA3       ; отобразим его с содержимым 

; 
; Запуск программы по адресу на дисплее  
; 
RUN:
    LXI H, 9D3H         ; Команда квлючения защтьы ОЗУ 
RUN1:
    SHLD RAML1          ; Запишем ее
    LXI H, 0C300H       ; Команда перехода на программу 
    SHLD RAML2          ; Пользователя (JMP USER)
    LXI SP, SAVRG       ; Адрес программы пользователя 
    PUSH B              
    LXI H, SAVSH        ; Восстановим старший байт SP 
    MVI M, 0BH          ; Пользователя 
    DCX H               
    MOV A, M            
    CPI 40H             ; Проверим не вышел ли он за 
                        ; Границу отведенной области 
    JNC RUN2            ; Если нет 
    MVI M, 0B0H         ; Иначе установим его заново 
RUN2:
    LXI SP, SAVE        ; Загрузим регистры пользователя 
    POP D               
    POP B               
    POP PSW             
    LXI SP, SAVSL       ; Восстановим младший байт SP 
    POP H               ; Пользователя
    SPHL                ; Перезагрузим SP 
    LHLD SAVL           
    JMP RAML1           ; Запуск программы пользователя 

; 
; Шаг команды 
; 
INSS: 
    LXI H, 0ED3H        ; Включение защиты ОЗУ и признака
                        ; Шаг команды 
    JMP RUN1            ; Звгрузка регистров и пуск 

; 
; Шаг цикла 
; 
HDSS: 
    LXI H, TSAVH        ; Включение защиты ОЗУ и признака
                        ; Шаг цикла 
    JMP RUN1            ; Звгрузка регистров и пуск 

; 
; Уменьшение номера отображаемого регистра  
; 
DCRR: 
    POP D               ; Освободить стек 
    INX B               ; Указатель - на область следующего РГ 
    LHLD RMP            ; Указатель сообщения о текущем РГ 
    DCX H 
    DCX H 
    MVI A, 0E8H         ; Посмотрели все регистры?
    CMP C 
    JNZ FETR1           ; Нет 
    LXI B, SAVPC        ; Да, начнем сначала
    LXI H, PCL 
    JMP FETR1 

; 
; Запись данных в регистр и увеличение его номера 
; 
STRR:
    POP D               ; Освободить стек 
    CALL FETA6          ; Упакуем данные с дисплея 
    STAX B              ; Запомним 
    DCX B               ; Указатель - на область следующего РГ 
    LHLD RMP            ; Указатель сообщения в текущем РГ 
    INX H 
    INX H 
    INX H 
    INX H 
    MVI A, 0DBH         ; Посмотрели все регистры?
    CMP C 
    JZ FETR             ; Да
    JMP FETR2           ; Нет 

; 
; Задержка примерно на 1 МС
; 
DELA:
    PUSH B 
    LXI B, 1        ; Фиксированное значение 1 МС 
    JMP DEL1

; 
; Задержка с длительностью, задаваемой BC в МС 
; 
DELB: 
    PUSH B 
DEL1:
    PUSH PSW 
    XRA A 
    PUSH D 
DEL2: 
    MVI D, TIME         ; Цикл задержки в 1 МС 
DEL3: 
    DCR D               ; Счетчик этого цикла 
    JNZ DEL3 
    DCX B               ; Счетчик количества МС 
    CMP B 
    JNZ DEL2 
    CMP C 
    JNZ DEL2            ; Еще не кончили 
    POP D 
    POP PSW 
    POP B 
    RET 

; 
; Генерация звукового сигнала
; 
BEEP2:
    MVI L, 0FFH     ; Множитель длительности 
    MVI H, 0        ; Выходной флаг 
    MOV C, B        ; Счетчик частоты 
    MOV E, D        ; Счетчик длительности 
    PUSH H 
BEEP3:
    DCR C 
    JNZ BEEP6       ; Задержка на полпериода частоты 
    MOV C, B        ; Восстанавливаем счетчик частоты 
    MOV A, H        ; Инвертируем выходной флаг 
    CMA 
    ORA A 
    MOV H, A
    JNZ BEEP4       ; Проверка выходного флага
    XRA A 
    OUT OTR         ; Выключили выход 
    JMP BEEP5     
BEEP4:
    MVI A, 0FFH     ; Включим вход 
    OUT OTR 
    NOP
BEEP5: 
    POP PSW 
    PUSH PSW 
    ORA A 
    JZ BEEP6        ; Продолжаем, если не закончили
    MOV A, H        ; Возвращаемся, если выход выключен
    ORA A 
    JZ BEEP7
BEEP6:
    DCR E           ; Счетчик длительности 
    JNZ BEEP3 
    MOV E, D        ; Восстанавливаем его 
    DCR L 
    JNZ BEEP3 
    POP PSW 
    CMA 
    PUSH PSW 
    JMP BEEP3 
BEEP7:
    POP PSW 
    RET
;
; Unknown section
;
DB  011h 
DB  0DBh 
DB  004h 
DB  0DFh 
DB  011h 
DB  0FFh 
DB  000h 
DB  0AFh 
DB  032h 
DB  0F6h 
DB  00Bh 
DB  0CDh 
DB  0E9h 
DB  001h 
DB  006h 
DB  01Fh 
DB  005h 
DB  029h 
DB  0C2h 
DB  091h 
DB  004h 
DB  03Eh 
DB  0FBh 
DB  0D3h 
DB  007h 
DB  0DBh 
DB  006h 
DB  0FEh 
DB  0FEh 
DB  0CAh 
DB  081h 
DB  004h 
DB  03Eh 
DB  0F7h 
DB  0D3h 
DB  007h 
DB  0DBh 
DB  006h 
DB  0FEh 
DB  0FEh 
DB  0C2h 
DB  0D6h 
DB  004h 
DB  0BBh 
DB  0CAh 
DB  0B2h 
DB  004h 
DB  05Fh 
DB  014h 
DB  07Ah 
DB  01Fh 
DB  0D2h 
DB  088h 
DB  004h 
DB  021h 
DB  0F0h 
DB  00Bh 
DB  034h 
DB  07Eh 
DB  0FEh 
DB  00Ah 
DB  0C2h 
DB  0C7h 
DB  004h 
DB  036h 
DB  000h 
DB  02Ch 
DB  0C3h 
DB  0BAh 
DB  004h 
DB  021h 
DB  0F3h 
DB  00Bh 
DB  07Eh 
DB  0FEh 
DB  006h 
DB  0C2h 
DB  088h 
DB  004h 
DB  036h 
DB  000h 
DB  02Ch 
DB  0C3h 
DB  0C3h 
DB  004h 
DB  01Eh 
DB  0FFh 
DB  0C3h 
DB  0B2h 
DB  004h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  019h 
DB  000h 
DB  001h 
DB  000h 
DB  000h 
DB  03Eh 
DB  001h 
DB  0A7h 
DB  0F5h 
DB  0A3h 
DB  078h 
DB  0CAh 
DB  0EEh 
DB  004h 
DB  082h 
DB  01Fh 
DB  047h 
DB  079h 
DB  01Fh 
DB  04Fh 
DB  0F1h 
DB  017h 
DB  0D2h 
DB  0E7h 
DB  004h 
DB  0C9h 
DB  000h 
DB  016h 
DB  000h 
DB  0CDh 
DB  09Ah 
DB  001h 
DB  0CDh 
DB  01Ch 
DB  005h 
DB  0B7h 
DB  0CAh 
DB  0FCh 
DB  004h 
DB  0CDh 
DB  00Fh 
DB  005h 
DB  0CDh 
DB  016h 
DB  005h 
DB  0C3h 
DB  0FCh 
DB  004h 
DB  03Dh 
DB  000h 
DB  000h 
DB  0C2h 
DB  00Fh 
DB  005h 
DB  0C9h 
DB  07Ah 
DB  02Fh 
DB  057h 
DB  0D3h 
DB  004h 
DB  0C9h 
DB  006h 
DB  007h 
DB  021h 
DB  0EFh 
DB  00Bh 
DB  07Eh 
DB  02Fh 
DB  0B7h 
DB  0CAh 
DB  039h 
DB  005h 
DB  0FEh 
DB  004h 
DB  0C2h 
DB  02Dh 
DB  005h 
DB  03Dh 
DB  04Fh 
DB  078h 
DB  007h 
DB  007h 
DB  0B1h 
DB  021h 
DB  03Ah 
DB  005h 
DB  085h 
DB  06Fh 
DB  07Eh 
DB  0C9h 
DB  005h 
DB  02Bh 
DB  078h 
DB  0FEh 
DB  001h 
DB  0C2h 
DB  021h 
DB  005h 
DB  0AFh 
DB  0C9h 
DB  0E6h 
DB  000h 
DB  000h 
DB  000h 
DB  0DAh 
DB  0BDh 
DB  0A3h 
DB  000h 
DB  08Fh 
DB  085h 
DB  072h 
DB  000h 
DB  064h 
DB  05Ch 
DB  04Dh 
DB  000h 
DB  043h 
DB  038h 
DB  033h 
DB  000h 
DB  02Dh 
DB  024h 
DB  020h 
DB  021h 
DB  08Dh 
DB  005h 
DB  0D5h 
DB  01Ah 
DB  0E6h 
DB  0F0h 
DB  0CAh 
DB  066h 
DB  005h 
DB  02Eh 
DB  099h 
DB  01Ah 
DB  0E6h 
DB  00Fh 
DB  0CAh 
DB  084h 
DB  005h 
DB  0FEh 
DB  00Dh 
DB  0DAh 
DB  073h 
DB  005h 
DB  03Eh 
DB  00Ch 
DB  0D6h 
DB  001h 
DB  085h 
DB  06Fh 
DB  046h 
DB  0CDh 
DB  012h 
DB  000h 
DB  0D1h 
DB  013h 
DB  01Ah 
DB  02Fh 
DB  0A7h 
DB  0C8h 
DB  0C3h 
DB  05Ah 
DB  005h 
DB  001h 
DB  080h 
DB  000h 
DB  0CDh 
DB  030h 
DB  004h 
DB  0C3h 
DB  07Bh 
DB  005h 
DB  0A1h 
DB  098h 
DB  08Fh 
DB  087h 
DB  07Fh 
DB  078h 
DB  071h 
DB  06Bh 
DB  064h 
DB  05Fh 
DB  059h 
DB  054h 
DB  04Fh 
DB  04Ah 
DB  046h 
DB  042h 
DB  03Eh 
DB  03Ah 
DB  037h 
DB  034h 
DB  031h 
DB  02Eh 
DB  02Bh 
DB  028h 
DB  006h 
DB  000h 
DB  006h 
DB  000h 
DB  006h 
DB  000h 
DB  001h 
DB  001h 
DB  001h 
DB  001h 
DB  0FFh 
DB  011h 
DB  000h 
DB  006h 
DB  0CDh 
DB  05Ah 
DB  005h 
DB  0CFh 
DB  0C3h 
DB  0B0h 
DB  005h 
DB  011h 
DB  0C4h 
DB  005h 
DB  0CDh 
DB  05Ah 
DB  005h 
DB  0CFh 
DB  0C3h 
DB  0BAh 
DB  005h 
DB  001h 
DB  004h 
DB  008h 
DB  004h 
DB  006h 
DB  006h 
DB  004h 
DB  003h 
DB  008h 
DB  008h 
DB  006h 
DB  006h 
DB  001h 
DB  001h 
DB  001h 
DB  000h 
DB  004h 
DB  008h 
DB  00Bh 
DB  00Bh 
DB  011h 
DB  011h 
DB  00Bh 
DB  009h 
DB  008h 
DB  008h 
DB  008h 
DB  000h 
DB  00Ah 
DB  00Ah 
DB  00Ch 
DB  00Ch 
DB  013h 
DB  011h 
DB  008h 
DB  008h 
DB  000h 
DB  003h 
DB  003h 
DB  001h 
DB  008h 
DB  006h 
DB  009h 
DB  009h 
DB  009h 
DB  000h 
DB  00Bh 
DB  009h 
DB  008h 
DB  008h 
DB  006h 
DB  004h 
DB  008h 
DB  008h 
DB  006h 
DB  006h 
DB  011h 
DB  011h 
DB  011h 
DB  0FFh 
DB  000h 
DB  01Ah 
DB  01Bh 
DB  01Ah 
DB  01Ah 
DB  01Ah 
DB  01Ah 
DB  01Ah 
DB  000h 
DB  00Ah 
DB  00Bh 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  000h 
DB  00Ah 
DB  00Bh 
DB  00Ah 
DB  00Ah 
DB  003h 
DB  005h 
DB  006h 
DB  003h 
DB  00Ah 
DB  00Bh 
DB  00Ah 
DB  00Ah 
DB  005h 
DB  006h 
DB  008h 
DB  005h 
DB  00Ah 
DB  00Bh 
DB  00Ah 
DB  00Ah 
DB  005h 
DB  006h 
DB  008h 
DB  008h 
DB  00Ah 
DB  00Bh 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  000h 
DB  013h 
DB  014h 
DB  013h 
DB  013h 
DB  00Ah 
DB  00Bh 
DB  011h 
DB  00Ah 
DB  013h 
DB  014h 
DB  013h 
DB  013h 
DB  008h 
DB  00Ah 
DB  00Bh 
DB  013h 
DB  011h 
DB  00Bh 
DB  013h 
DB  013h 
DB  00Ah 
DB  006h 
DB  005h 
DB  005h 
DB  008h 
DB  006h 
DB  003h 
DB  003h 
DB  003h 
DB  003h 
DB  003h 
DB  000h 
DB  003h 
DB  006h 
DB  006h 
DB  006h 
DB  005h 
DB  005h 
DB  000h 
DB  000h 
DB  005h 
DB  008h 
DB  008h 
DB  008h 
DB  006h 
DB  006h 
DB  000h 
DB  000h 
DB  006h 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  008h 
DB  008h 
DB  000h 
DB  000h 
DB  00Bh 
DB  00Ah 
DB  011h 
DB  011h 
DB  011h 
DB  011h 
DB  011h 
DB  000h 
DB  00Ah 
DB  011h 
DB  011h 
DB  011h 
DB  00Bh 
DB  00Bh 
DB  000h 
DB  000h 
DB  008h 
DB  00Bh 
DB  00Bh 
DB  00Bh 
DB  00Ah 
DB  00Ah 
DB  000h 
DB  000h 
DB  006h 
DB  00Ah 
DB  008h 
DB  008h 
DB  000h 
DB  000h 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  00Ah 
DB  003h 
DB  003h 
DB  000h 
DB  003h 
DB  005h 
DB  006h 
DB  00Ah 
DB  011h 
DB  00Bh 
DB  00Ah 
DB  00Bh 
DB  00Ah 
DB  008h 
DB  006h 
DB  005h 
DB  003h 
DB  003h 
DB  000h 
DB  013h 
DB  013h 
DB  0FFh 
DB  011h 
DB  0A5h 
DB  005h 
DB  0CDh 
DB  05Ah 
DB  005h 
DB  0C9h 
DB  000h 
DB  0F5h 
DB  0D5h 
DB  0C5h 
DB  0D5h 
DB  0DFh 
DB  0D1h 
DB  006h 
DB  004h 
DB  021h 
DB  0F5h 
DB  00Bh 
DB  0CDh 
DB  04Bh 
DB  001h 
DB  0FEh 
DB  081h 
DB  0CAh 
DB  0ABh 
DB  006h 
DB  0FEh 
DB  010h 
DB  0D2h 
DB  0B3h 
DB  006h 
DB  077h 
DB  005h 
DB  02Bh 
DB  0C2h 
DB  0B3h 
DB  006h 
DB  0CDh 
DB  04Bh 
DB  001h 
DB  0FEh 
DB  081h 
DB  0CAh 
DB  0ABh 
DB  006h 
DB  0FEh 
DB  083h 
DB  0C2h 
DB  0C6h 
DB  006h 
DB  021h 
DB  0F4h 
DB  00Bh 
DB  0CDh 
DB  093h 
DB  003h 
DB  057h 
DB  021h 
DB  0F2h 
DB  00Bh 
DB  0CDh 
DB  093h 
DB  003h 
DB  05Fh 
DB  0D5h 
DB  0D7h 
DB  0E1h 
DB  0C1h 
DB  0D1h 
DB  0F1h 
DB  0C9h 
DB  014h 
DB  000h 
DB  017h 
DB  017h 
DB  017h 
DB  017h 
DB  0D5h 
DB  0EBh 
DB  02Ah 
DB  002h 
DB  00Bh 
DB  0CDh 
DB  0FAh 
DB  006h 
DB  0EBh 
DB  0D1h 
DB  023h 
DB  0C9h 
DB  07Ch 
DB  0BAh 
DB  0C0h 
DB  07Dh 
DB  0BBh 
DB  0C9h 
DB  0C5h 
DB  00Eh 
DB  008h 
DB  007h 
DB  02Fh 
DB  0D3h 
DB  004h 
DB  0CDh 
DB  016h 
DB  007h 
DB  02Fh 
DB  0D3h 
DB  004h 
DB  0CDh 
DB  016h 
DB  007h 
DB  00Dh 
DB  0C2h 
DB  003h 
DB  007h 
DB  0C1h 
DB  0C9h 
DB  006h 
DB  030h 
DB  005h 
DB  0C2h 
DB  018h 
DB  007h 
DB  0C9h 
DB  00Eh 
DB  001h 
DB  0DBh 
DB  004h 
DB  047h 
DB  0DBh 
DB  004h 
DB  0B8h 
DB  0CAh 
DB  022h 
DB  007h 
DB  006h 
DB  048h 
DB  0CDh 
DB  018h 
DB  007h 
DB  00Fh 
DB  079h 
DB  017h 
DB  04Fh 
DB  0D2h 
DB  01Fh 
DB  007h 
DB  03Ah 
DB  006h 
DB  00Bh 
DB  0A9h 
DB  0C9h 
DB  0AFh 
DB  032h 
DB  006h 
DB  00Bh 
DB  0F6h 
DB  080h 
DB  04Fh 
DB  0CDh 
DB  01Fh 
DB  007h 
DB  0FEh 
DB  0E6h 
DB  0C8h 
DB  0FEh 
DB  019h 
DB  0C2h 
DB  03Dh 
DB  007h 
DB  03Eh 
DB  0FFh 
DB  032h 
DB  006h 
DB  00Bh 
DB  0C9h 
DB  07Bh 
DB  0CDh 
DB  000h 
DB  007h 
DB  0CFh 
DB  011h 
DB  0E8h 
DB  006h 
DB  0CDh 
DB  0A8h 
DB  006h 
DB  022h 
DB  000h 
DB  00Bh 
DB  0CDh 
DB  0A8h 
DB  006h 
DB  022h 
DB  002h 
DB  00Bh 
DB  011h 
DB  0DCh 
DB  007h 
DB  0CDh 
DB  0A8h 
DB  006h 
DB  022h 
DB  004h 
DB  00Bh 
DB  0AFh 
DB  047h 
DB  0CDh 
DB  000h 
DB  007h 
DB  005h 
DB  0C2h 
DB  070h 
DB  007h 
DB  021h 
DB  0FFh 
DB  00Ah 
DB  016h 
DB  008h 
DB  05Fh 
DB  03Eh 
DB  0E6h 
DB  015h 
DB  0C2h 
DB  088h 
DB  007h 
DB  02Ah 
DB  000h 
DB  00Bh 
DB  02Bh 
DB  07Bh 
DB  0CDh 
DB  000h 
DB  007h 
DB  083h 
DB  05Fh 
DB  0CDh 
DB  0EEh 
DB  006h 
DB  0CAh 
DB  051h 
DB  007h 
DB  07Eh 
DB  015h 
DB  014h 
DB  0CAh 
DB  088h 
DB  007h 
DB  0C3h 
DB  07Fh 
DB  007h 
DB  0CDh 
DB  01Dh 
DB  007h 
DB  0BBh 
DB  02Ah 
DB  004h 
DB  00Bh 
DB  0CAh 
DB  0D8h 
DB  007h 
DB  0CFh 
DB  0D3h 
DB  010h 
DB  0CDh 
DB  039h 
DB  007h 
DB  021h 
DB  000h 
DB  00Bh 
DB  011h 
DB  0E6h 
DB  007h 
DB  0CDh 
DB  01Dh 
DB  007h 
DB  015h 
DB  0C2h 
DB  0C4h 
DB  007h 
DB  0BBh 
DB  0C4h 
DB  038h 
DB  000h 
DB  02Ah 
DB  000h 
DB  00Bh 
DB  02Bh 
DB  0C3h 
DB  0C5h 
DB  007h 
DB  077h 
DB  083h 
DB  05Fh 
DB  0CDh 
DB  0EEh 
DB  006h 
DB  0CAh 
DB  09Ch 
DB  007h 
DB  014h 
DB  0FAh 
DB  0B2h 
DB  007h 
DB  015h 
DB  0C3h 
DB  0B2h 
DB  007h 
DB  000h 
DB  000h 
DB  000h 
DB  0D3h 
DB  00Eh 
DB  000h 
DB  0E9h 
DB  00Dh 
DB  00Ah 
DB  017h 
DB  017h 
DB  017h 
DB  017h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h 
DB  000h