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
BEEP1:
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
    CMP M
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


;
; Секундомер
;   кл. 0 - сброс
;   кл. 1 - пуск/останов
; 
STWCH:
    LXI D, 04DBH
    RST 3
    LXI D, 00FFH
STWC1:
    XRA A
    STA 0BF6h
    CALL DCD
    MVI B, 1FH
STWC2:
    DCR B
    DAD H
    JNZ STWC2
    MVI A, 0FBH
    OUT 07H
    IN 06H
    CPI 0FEH
    JZ STWCH
    MVI A, 0F7H
    OUT 07H
    IN 06H
    CPI 0FEH
    JNZ STWC7
    CMP E
    JZ STWC3
    MOV E, A
    INR D
STWC3:
    MOV A, D
    RAR
    JNC STWC1
    LXI H, 0BF0H
STWC4:
    INR M
    MOV A, M
    CPI 0AH
    JNZ STWC6
    MVI M, 00H
STWC5:
    INR L
    JMP STWC4
STWC6:
    LXI H, 0BF3H
    MOV A, M
    CPI 06H
    JNZ STWC1
    MVI M, 00H  
    INR L
    JMP STWC5
STWC7:
    MVI E, 0FFH
    JMP STWC3
    NOP
    NOP
    NOP
    NOP
    DAD D
    NOP

; 
; Умножение однобайтных чисел
;   Вход:
;       рег. E - множитель
;       рег. D - множимое
; 
;   Выход:
;       BC - результат
; 
MULTY:
    LXI B, 0000H        ; Обнуление BC
    MVI A, 01H          ; 
    ANA A               ; Сброс флагов
MULT1:
    PUSH PSW            ; Сохранение флагов и аккумулятора
    ANA E               
    MOV A, B
    JZ MULT2
    ADD D
MULT2:
    RAR
    MOV B, A
    MOV A, C
    RAR
    MOV C, A
    POP PSW
    RAL
    JNC MULT1   
    RET
    NOP
    MVI D, 00H  

; 
; Орган
; 
ORGN:
    CALL KRD
    CALL ORGN3
    ORA A
    JZ ORGN
    CALL ORGN1
    CALL ORGN2
    JMP ORGN
ORGN1:
    DCR A
    NOP
    NOP
    JNZ ORGN1   
    RET
ORGN2:
    MOV A,D
    CMA
    MOV D,A 
    OUT 04H 
    RET
ORGN3:
    MVI B,07H   
    LXI H,0BEFH
ORGN4:
    MOV A,M
    CMA 
    ORA A
    JZ ORGN6
    CPI 04H
    JNZ ORGN5
    DCR A
ORGN5:
    MOV C,A
    MOV A,B
    RLC 
    RLC
    ORA C
    LXI H,053AH
    ADD L   
    MOV L,A
    MOV A,M
    RET
ORGN6:
    DCR B
    DCX H
    MOV A,B
    CPI 01H
    JNZ ORGN4
    XRA A
    RET

DB 0E6h, 000h, 000h, 000h 
DB 0DAh, 0BDh, 0A3h, 000h 
DB 08Fh, 085h, 072h, 000h 
DB 064h, 05Ch, 04Dh, 000h 
DB 043h, 038h, 033h, 000h 
DB 02Dh, 024h, 020h,

; 055AH
M0:
    LXI H, 058Dh
    PUSH D 
    LDAX D 
    ANI 0F0H 
    JZ M1
    MVI L, 99H 
M1:
    LDAX D 
    ANI 0FH 
    JZ M2
    CPI 0DH 
    JC M3
    MVI A, 0CH 
M3:
    SUI 01H 
    ADD L 
    MOV L, A 
    MOV B, M 
    CALL BEEP1
M4:
    POP D 
    INX D 
    LDAX D 
    CMA 
    ANA A 
    RZ 
    JMP M0
M2:
    LXI B, 0080H 
    CALL DELB 
    JMP M4

    DB 0A1h, 098h, 08Fh, 087h 
    DB 07Fh, 078h, 071h, 06Bh 
    DB 064h, 05Fh, 059h, 054h 
    DB 04Fh, 04Ah, 046h, 042h
    DB 03Eh, 03Ah, 037h, 034h 
    DB 031h, 02Eh, 02Bh, 028h 
    
MSTRT:
    DB 006h, 000h, 006h, 000h 
    DB 006h, 000h, 001h, 001h 
    DB 001h, 001h, 0FFh

; 
; ♫♫♫ Мелодия. ♫♫♫
; Крокодил Гена - "Пусть бегут неуклюже"
; 
MUS01:
    LXI D, MGENA
    CALL 055AH          ; ?
    RST 1
    JMP MUS01 

; 
; ♫♫♫ Мелодия 2. ♫♫♫
; ???
; 
MUS02:
    LXI D, MUNK
    CALL 055AH          ; ?
    RST 1
    JMP MUS02 

; 
; ♫♫♫ Мелодия 2. ♫♫♫
; ???
; 
MUNK:
    DB 001h, 004h, 008h, 004h 
    DB 006h, 006h, 004h, 003h
    DB 008h, 008h, 006h, 006h
    DB 001h, 001h, 001h, 000h 
    DB 004h, 008h, 00Bh, 00Bh 
    DB 011h, 011h, 00Bh, 009h 
    DB 008h, 008h, 008h, 000h
    DB 00Ah, 00Ah, 00Ch, 00Ch 
    DB 013h, 011h, 008h, 008h
    DB 000h, 003h, 003h, 001h 
    DB 008h, 006h, 009h, 009h
    DB 009h, 000h, 00Bh, 009h
    DB 008h, 008h, 006h, 004h 
    DB 008h, 008h, 006h, 006h 
    DB 011h, 011h, 011h, 0FFh

; 
; ♫♫♫ Мелодия 1. ♫♫♫
; Крокодил Гена - "Пусть бегут неуклюже"
; 
MGENA:
    DB 000h, 01Ah, 01Bh, 01Ah 
    DB 01Ah, 01Ah, 01Ah, 01Ah 
    DB 000h, 00Ah, 00Bh, 00Ah 
    DB 00Ah, 00Ah, 00Ah, 00Ah
    DB 000h, 00Ah, 00Bh, 00Ah 
    DB 00Ah, 003h, 005h, 006h 
    DB 003h, 00Ah, 00Bh, 00Ah 
    DB 00Ah, 005h, 006h, 008h
    DB 005h, 00Ah, 00Bh, 00Ah 
    DB 00Ah, 005h, 006h, 008h 
    DB 008h, 00Ah, 00Bh, 00Ah 
    DB 00Ah, 00Ah, 00Ah, 00Ah
    DB 000h, 013h, 014h, 013h 
    DB 013h, 00Ah, 00Bh, 011h 
    DB 00Ah, 013h, 014h, 013h 
    DB 013h, 008h, 00Ah, 00Bh
    DB 013h, 011h, 00Bh, 013h 
    DB 013h, 00Ah, 006h, 005h 
    DB 005h, 008h, 006h, 003h 
    DB 003h, 003h, 003h, 003h
    DB 000h, 003h, 006h, 006h 
    DB 006h, 005h, 005h, 000h 
    DB 000h, 005h, 008h, 008h 
    DB 008h, 006h, 006h, 000h
    DB 000h, 006h, 00Ah, 00Ah 
    DB 00Ah, 008h, 008h, 000h 
    DB 000h, 00Bh, 00Ah, 011h 
    DB 011h, 011h, 011h, 011h
    DB 000h, 00Ah, 011h, 011h 
    DB 011h, 00Bh, 00Bh, 000h 
    DB 000h, 008h, 00Bh, 00Bh 
    DB 00Bh, 00Ah, 00Ah, 000h
    DB 000h, 006h, 00Ah, 008h 
    DB 008h, 000h, 000h, 00Ah 
    DB 00Ah, 00Ah, 00Ah, 003h 
    DB 003h, 000h, 003h, 005h
    DB 006h, 00Ah, 011h, 00Bh 
    DB 00Ah, 00Bh, 00Ah, 008h
    DB 006h, 005h, 003h, 003h
    DB 000h, 013h, 013h, 0FFh

; 
; Стартовая мелодия
; 
LMC:
    LXI D, MSTRT
    CALL  055Ah
    RET
    NOP


; 
; ???????
; 06A8
; 
MM0:
    PUSH PSW 
    PUSH D 
    PUSH B 
MM1:
    PUSH D 
    RST 3 
    POP D 
    MVI B, 04H 
    LXI H, 0BF5H 
MM2:
    CALL KIND 
    CPI  81h
    JZ  MM1
    CPI  10h
    JNC  MM2
    MOV M, A 
    DCR B 
    DCX H 
    JNZ  MM2
MM3:
    CALL  KIND
    CPI  81h
    JZ  MM1
    CPI  83h
    JNZ  MM3
    LXI H, 0BF4h
    CALL  FETA6
    MOV D, A 
    LXI H, 0BF2h
    CALL  FETA6
    MOV E, A 
    PUSH D
    RST 2
    POP H
    POP B
    POP D
    POP PSW
    RET 

; 
; ????
; 
INR D 
NOP 
RAL 
RAL 
RAL 
RAL 

; ????
MMM0:
    PUSH D 
    XCHG 
    LHLD  0B02h
    CALL  MMM1
    XCHG 
    POP D
    INX H 
    RET 
MMM1:
    MOV A, H 
    CMP D 
    RNZ 
    MOV A, L 
    CMP E 
    RET 

MMMM0:
    PUSH B 
    MVI C, 08H 
MMMM2:
    RLC 
    CMA 
    OUT 04H 
    CALL MMMM1 
    CMA 
    OUT 04H 
    CALL MMMM1 
    DCR C 
    JNZ MMMM2 
    POP B 
    RET 
MMMM1:
    MVI B, 30H 
MMMM3:
    DCR B 
    JNZ MMMM3
    RET 
MMMM11:
    MVI C, 01H 
MMMM5:   
    IN 04H 
    MOV B, A 
MMMM4:    
    IN 04H 
    CMP B 
    JZ MMMM4 
    MVI B, 48H 
    CALL MMMM3 
    RRC 
    MOV A, C 
    RAL 
    MOV C, A 
    JNC MMMM5 
    LDA 0B06H 
    XRA C 
    RET 
MMMM13:
    XRA A
    STA 0B06H 
MMMM6:    
    ORI 80H 
    MOV C, A 
    CALL MMMM5 
    CPI 0E6H
    RZ 
    CPI 19H 
    JNZ MMMM6 
    MVI A, 0FFH 
    STA 0B06H 
    RET 
MMMM9:
    MOV A, E 
    CALL MMMM0 

    RST 1 
    LXI D, 06E8h
    CALL  MM0
    SHLD  0B00h
    CALL  MM0
    SHLD  0B02h
    LXI D, 07DCh
    CALL  MM0
    SHLD  0B04h
    XRA A 
    MOV B, A 
MMMM7:  
    CALL  MMMM0
    DCR B 
    JNZ  MMMM7
    LXI H, 0AFFh
    MVI D, 08h
    MOV E, A 
    MVI A, 0E6h
MMMM10:    
    DCR D 
    JNZ  MMMM8
    LHLD  0B00h
    DCX H   
    MOV A, E 
MMMM8:
    CALL  MMMM0
    ADD E 
    MOV E, A 
    CALL  MMM0
    JZ  MMMM9
    MOV A, M 
    DCR D 
    INR D 
    JZ  MMMM8
    JMP  MMMM10
MMMM16:  
    CALL  MMMM11
    CMP E 
    LHLD  0B04h
    JZ  MMMM12
    RST 1 
    OUT  10h
    CALL  MMMM13
    LXI H, 0B00h
    LXI D, 07E6h
MMMM17:   
    CALL  MMMM11
    DCR D 
    JNZ  MMMM14
    CMP E 

    CNZ  RS7
    LHLD  0B00h
    DCX H 
    JMP  MMMM15
MMMM14:
    MOV M, A 
MMMM15:
    ADD E 
    MOV E, A 
    CALL  MMM0
    JZ  MMMM16
    INR D 
    JM  MMMM17
    DCR D 
    JMP  MMMM17
    NOP 
    NOP 
    NOP 
MMMM12:
    OUT  0Eh
    NOP 
    PCHL 
    DCR C 
    LDAX B 
    RAL 
    RAL 
    RAL 
    RAL 