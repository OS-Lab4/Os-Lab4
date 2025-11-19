#!/bin/bash

# Лабораторная работа № 4
# Скрипт для работы с файловой системой преподавателя

# Установка путей
BASE_DIR="labfiles-25"
STUDENTS_DIR="$BASE_DIR/students"
GROUPS_DIR="$STUDENTS_DIR/groups"
NOTES_DIR="$STUDENTS_DIR/general/notes"
POP_DIR="$BASE_DIR/Поп-Культуроведение"
CIRCUS_DIR="$BASE_DIR/Цирковое_Дело"

# Отключение расширения glob-паттернов, если нет совпадений
shopt -s nullglob

# ==================== ФУНКЦИИ СПРАВКИ ====================

print_help() {
    cat << EOF
Использование: ./lab4.sh [ФЛАГ] [АРГУМЕНТЫ]

ФЛАГИ:
  -h, --help                     Показать эту справку

  --best-grades <группа>         Вывод студентов с максимальным количеством
                                 троек, четвёрок и пятёрок по тестам

  --performance <группа>         Вывод списка группы, упорядоченного по
                                 успеваемости (средний балл)

  --dossier-student <фамилия>    Вывод досье студента по фамилии

  --dossier-group <группа>       Вывод досье всех студентов группы

  --dossier-all                  Вывод всех досье студентов

ФОРМАТ НОМЕРА ГРУППЫ:
  A-XX-XX или Ae-XX-XX (например: A-06-04, Ae-21-22)

ПРИМЕРЫ:
  ./lab4.sh --best-grades A-06-22
  ./lab4.sh --performance Ae-21-22
  ./lab4.sh --dossier-student RomanovDanA
  ./lab4.sh --dossier-group A-06-22
  ./lab4.sh --dossier-all

EOF
}

# ==================== ВАЛИДАЦИЯ ====================

validate_group() {
    local group="$1"

    # Проверка формата группы
    if ! [[ "$group" =~ ^(A|Ae)-[0-9]{2}-[0-9]{2}$ ]]; then
        printf "%s\n" "Ошибка: Номер группы не соответствует формату (A-XX-XX или Ae-XX-XX)"
        exit 1
    fi

    # Проверка существования файла группы
    if [[ ! -f "$GROUPS_DIR/$group" ]]; then
        printf "%s\n" "Ошибка: Группа '$group' не существует"
        printf "%s\n" "Доступные группы:"
        ls "$GROUPS_DIR" | head -10
        exit 1
    fi

    # Проверка прав на чтение
    if [[ ! -r "$GROUPS_DIR/$group" ]]; then
        printf "%s\n" "Ошибка: Нет прав на чтение файла группы '$group'"
        exit 1
    fi
}

validate_student() {
    local student="$1"
    local first_letter="${student:0:1}"
    local file="$NOTES_DIR/${first_letter}Names.log"

    if [[ ! -f "$file" ]]; then
        printf "%s\n" "Ошибка: Файл досье '${first_letter}Names.log' не найден"
        exit 1
    fi

    if [[ ! -r "$file" ]]; then
        printf "%s\n" "Ошибка: Нет прав на чтение файла досье"
        exit 1
    fi

    # Проверка существования студента в досье
    if ! grep -q "^$student$" "$file" 2>/dev/null; then
        printf "%s\n" "Ошибка: У студента '$student' нет досье"
        exit 1
    fi
}

# ==================== ОСНОВНЫЕ ФУНКЦИИ ====================

# Функция для подсчёта количества оценок по каждому типу
count_grades() {
    local group="$1"

    printf "\n"
    printf '%*s\n' 34 '' | tr ' ' '='
    printf "%s\n" "Анализ оценок для группы '$group'"
    printf '%*s\n' 34 '' | tr ' ' '='
    printf "\n"

    # Создаём временный файл для хранения данных
    local temp_file=$(mktemp)

    # Читаем список студентов группы и подсчитываем оценки
    while IFS= read -r student; do
        [[ -z "$student" ]] && continue

        local count_3=0
        local count_4=0
        local count_5=0

        # Проходим по всем тестам обоих предметов
        for subject_dir in "$POP_DIR" "$CIRCUS_DIR"; do
            for test_file in "$subject_dir/tests/TEST-"[1-4]; do
                [[ ! -f "$test_file" ]] && continue

                # Извлекаем оценки студента из теста
                while IFS=';' read -r test_group test_student test_date test_score test_grade; do
                    if [[ "$test_group" == "$group" && "$test_student" == "$student" ]]; then
                        # Определяем базовую оценку (без модификаторов + и -)
                        base_grade="${test_grade%%[+-]*}"
                        base_grade="${base_grade:0:1}"

                        case "$base_grade" in
                            3) count_3=$((count_3 + 1)) ;;
                            4) count_4=$((count_4 + 1)) ;;
                            5) count_5=$((count_5 + 1)) ;;
                        esac
                    fi
                done < "$test_file"
            done
        done

        # Записываем результаты в временный файл
        printf "%s\n" "$student|$count_3|$count_4|$count_5" >> "$temp_file"
    done < "$GROUPS_DIR/$group"

    # Находим студентов с максимальным количеством троек, четвёрок и пятёрок
    local best_3=$(sort -t'|' -k2 -rn "$temp_file" | head -1)
    local best_4=$(sort -t'|' -k3 -rn "$temp_file" | head -1)
    local best_5=$(sort -t'|' -k4 -rn "$temp_file" | head -1)

    # Вывод таблицы для троек
    printf "%s\n" "Максимальное количество оценок 3"
    printf "%-32s | %-21s | %-17s | %-17s | %-s\n"  "Студент" "Группа" "Кол-во 3" "Кол-во 4" "Кол-во 5"
    printf '%*s\n' 86 '' | tr ' ' '-'
    if [[ -n "$best_3" ]]; then
        IFS='|' read -r student c3 c4 c5 <<< "$best_3"
        printf "%-25s | %-15s | %-12s | %-12s | %-12s\n" "$student" "$group" "$c3" "$c4" "$c5"
    fi
    printf "\n"

    # Вывод таблицы для четвёрок
    printf "%s\n" "Максимальное количество оценок 4"
    printf "%-32s | %-21s | %-17s | %-17s | %-s\n"  "Студент" "Группа" "Кол-во 3" "Кол-во 4" "Кол-во 5"
    printf '%*s\n' 86 '' | tr ' ' '-'
    if [[ -n "$best_4" ]]; then
        IFS='|' read -r student c3 c4 c5 <<< "$best_4"
        printf "%-25s | %-15s | %-12s | %-12s | %-12s\n" "$student" "$group" "$c3" "$c4" "$c5"
    fi
    printf "\n"

    # Вывод таблицы для пятёрок
    printf "%s\n" "Максимальное количество оценок 5"
    printf "%-32s | %-21s | %-17s | %-17s | %-s\n"  "Студент" "Группа" "Кол-во 3" "Кол-во 4" "Кол-во 5"
    printf '%*s\n' 86 '' | tr ' ' '-'
    if [[ -n "$best_5" ]]; then
        IFS='|' read -r student c3 c4 c5 <<< "$best_5"
        printf "%-25s | %-15s | %-12s | %-12s | %-12s\n" "$student" "$group" "$c3" "$c4" "$c5"
    fi
    printf "\n"

    # Удаляем временный файл
    rm -f "$temp_file"
}

# Функция для конвертации оценок в числовой формат
convert_grade_to_number() {
    local grade="$1"
    case "$grade" in
        5++|5+) echo "5" ;;
        5) echo "5" ;;
        5-) echo "5" ;;
        4++|4+) echo "4" ;;
        4) echo "4" ;;
        4-) echo "4" ;;
        3++|3+) echo "3" ;;
        3) echo "3" ;;
        3-) echo "3" ;;
        2*) echo "2" ;;
        *) echo "0" ;;
    esac
}

# Функция для вывода списка группы по успеваемости
show_performance() {
    local group="$1"

    printf "\n"
    printf '%*s\n' 52 '' | tr ' ' '='
    printf "%s\n" "Сводная таблица с успеваемостью для группы '$group'"
    printf '%*s\n' 52 '' | tr ' ' '='
    printf "\n"

    # Создаём временный файл для хранения данных
    local temp_file=$(mktemp)

    # Читаем список студентов группы
    while IFS= read -r student; do
        [[ -z "$student" ]] && continue

        local pop_sum=0
        local pop_count=0
        local circus_sum=0
        local circus_count=0

        # Поп-Культуроведение
        for test_file in "$POP_DIR/tests/TEST-"[1-4]; do
            [[ ! -f "$test_file" ]] && continue

            while IFS=';' read -r test_group test_student test_date test_score test_grade; do
                if [[ "$test_group" == "$group" && "$test_student" == "$student" ]]; then
                    numeric_grade=$(convert_grade_to_number "$test_grade")
                    pop_sum=$((pop_sum + numeric_grade))
                    pop_count=$((pop_count + 1))
                fi
            done < "$test_file"
        done

        # Цирковое дело
        for test_file in "$CIRCUS_DIR/tests/TEST-"[1-4]; do
            [[ ! -f "$test_file" ]] && continue

            while IFS=';' read -r test_group test_student test_date test_score test_grade; do
                if [[ "$test_group" == "$group" && "$test_student" == "$student" ]]; then
                    numeric_grade=$(convert_grade_to_number "$test_grade")
                    circus_sum=$((circus_sum + numeric_grade))
                    circus_count=$((circus_count + 1))
                fi
            done < "$test_file"
        done

        # Вычисляем средние баллы
        local pop_avg
        local circus_avg
        local overall_avg

        if (( pop_count > 0 )); then
            pop_avg=$(awk "BEGIN {printf \"%.2f\", $pop_sum / $pop_count}")
        else
            pop_avg="0.00"
        fi

        if (( circus_count > 0 )); then
            circus_avg=$(awk "BEGIN {printf \"%.2f\", $circus_sum / $circus_count}")
        else
            circus_avg="0.00"
        fi

        # Общий средний балл
        local total_count=$((pop_count + circus_count))
        if (( total_count > 0 )); then
            overall_avg=$(awk "BEGIN {printf \"%.2f\", ($pop_sum + $circus_sum) / $total_count}")
        else
            overall_avg="0.00"
        fi

        # Записываем результаты в временный файл
        printf "%s\n" "$student|$pop_avg|$circus_avg|$overall_avg" >> "$temp_file"
    done < "$GROUPS_DIR/$group"

    # Вывод таблицы
    # Вручную добавляем пробелы к кириллическим заголовкам для выравнивания
    printf "%-33s | %-44s | %-31s | %-s\n"  "Студент" "Поп-Культуроведение" "Цирковое дело" "Общее усреднённое"
    printf '%*s\n' 98 '' | tr ' ' '-'

    # Сортируем по общему среднему баллу (по убыванию), затем по фамилии
    sort -t'|' -k4 -rn -k1 "$temp_file" | while IFS='|' read -r student pop_avg circus_avg overall_avg; do
        printf "%-26s | %-26s | %-19s | %-23s\n" "$student" "$pop_avg" "$circus_avg" "$overall_avg"
    done

    # Удаляем временный файл
    rm -f "$temp_file"
    printf "\n"
}

# Функция для вывода досье студента
show_dossier_student() {
    local student="$1"
    local first_letter="${student:0:1}"
    local file="$NOTES_DIR/${first_letter}Names.log"

    printf "\n"
    printf "%*s\n" 26 '' | tr ' ' '='
    printf "Досье студента: $student\n"
    printf "%*s\n" 26 '' | tr ' ' '='
    printf "\n"

    # Извлекаем досье с помощью sed
    # Ищем строку с именем студента, затем выводим следующую строку до следующего разделителя
    sed -n "/^$student$/,/^====/{
        /^$student$/d
        /^====/q
        p
    }" "$file"

    printf "\n"
}

# Функция для вывода досье всех студентов группы
show_dossier_group() {
    local group="$1"

    printf '%*s\n' 33 '' | tr ' ' '='
    printf "%s\n" "Досье студентов группы '$group'"
    printf '%*s\n' 33 '' | tr ' ' '='
    printf "\n"

    printf "%-37s | %-21s | %s\n" "Студент" "Группа" "Досье"
    printf '%*s\n' 60 '' | tr ' ' '-'

    while IFS= read -r student; do
        [[ -z "$student" ]] && continue

        local first_letter="${student:0:1}"
        local file="$NOTES_DIR/${first_letter}Names.log"

        if [[ -f "$file" ]] && grep -q "^$student$" "$file" 2>/dev/null; then
            # Извлекаем досье с помощью sed (как в show_dossier_student)
            dossier=$(sed -n "/^$student$/,/^====/{
                /^$student$/d
                /^====/q
                p
            }" "$file" | tr '\n' ' ' | sed 's/[[:space:]]*$//')

            printf "%-30s | %-15s | %s\n" "$student" "$group" "$dossier"
        else
            printf "%-30s | %-15s | %s\n" "$student" "$group" "Нет досье"
        fi
    done < "$GROUPS_DIR/$group"

    printf "\n"
}

# Функция для вывода всех досье
show_dossier_all() {
    printf "\n"
    printf '%*s\n' 19 '' | tr ' ' '='
    printf "%s\n" "Все досье студентов"
    printf '%*s\n' 19 '' | tr ' ' '='
    printf "\n"

    printf "%-37s | %-21s | %s\n" "Студент" "Группа" "Досье"
    printf '%*s\n' 60 '' | tr ' ' '-'

    for notes_file in "$NOTES_DIR"/*Names.log; do
        [[ ! -f "$notes_file" ]] && continue

        # Извлекаем имена студентов из файла - они идут после разделителя =====
        while IFS= read -r line; do
            # Пропускаем пустые строки и разделители
            [[ -z "$line" ]] && continue
            [[ "$line" =~ ^=+$ ]] && continue

            # Проверяем, является ли строка именем студента (начинается с заглавной буквы, без пробелов)
            if [[ "$line" =~ ^[A-Z][a-zA-Z-]*[A-Z]+$ ]]; then
                student="$line"

                # Находим группу студента
                group=""
                for group_file in "$GROUPS_DIR"/*; do
                    if grep -q "^$student$" "$group_file" 2>/dev/null; then
                        group=$(basename "$group_file")
                        break
                    fi
                done

                if [[ -z "$group" ]]; then
                    group="Не найдена"
                fi

                # Извлекаем досье
                dossier=$(sed -n "/^$student$/,/^====/{
                    /^$student$/d
                    /^====/q
                    p
                }" "$notes_file" | tr '\n' ' ' | sed 's/[[:space:]]*$//')

                printf "%-30s | %-15s | %s\n" "$student" "$group" "$dossier"
            fi
        done < "$notes_file"
    done

    printf "\n"
}

# ==================== ГЛАВНАЯ ЛОГИКА ====================

main() {
    # Проверка наличия аргументов
    if [[ $# -eq 0 ]]; then
        printf "%s\n" "Ошибка: Не указаны аргументы"
        printf "%s\n" "Используйте --help для справки"
        exit 1
    fi

    # Проверка существования базовой директории
    if [[ ! -d "$BASE_DIR" ]]; then
        printf "%s\n" "Ошибка: Директория '$BASE_DIR' не найдена"
        exit 1
    fi

    case "$1" in
        -h|--help)
            print_help
            ;;

        --best-grades)
            if [[ $# -ne 2 ]]; then
                printf "%s\n" "Ошибка: Неверное количество аргументов"
                printf "%s\n" "Использование: $0 --best-grades <группа>"
                exit 1
            fi
            validate_group "$2"
            count_grades "$2"
            ;;

        --performance)
            if [[ $# -ne 2 ]]; then
                printf "%s\n" "Ошибка: Неверное количество аргументов"
                printf "%s\n" "Использование: $0 --performance <группа>"
                exit 1
            fi
            validate_group "$2"
            show_performance "$2"
            ;;

        --dossier-student)
            if [[ $# -ne 2 ]]; then
                printf "%s\n" "Ошибка: Неверное количество аргументов"
                printf "%s\n" "Использование: $0 --dossier-student <ФамилияИО>"
                exit 1
            fi
            validate_student "$2"
            show_dossier_student "$2"
            ;;

        --dossier-group)
            if [[ $# -ne 2 ]]; then
                printf "%s\n" "Ошибка: Неверное количество аргументов"
                printf "%s\n" "Использование: $0 --dossier-group <группа>"
                exit 1
            fi
            validate_group "$2"
            show_dossier_group "$2"
            ;;

        --dossier-all)
            if [[ $# -ne 1 ]]; then
                printf "%s\n" "Ошибка: Флаг --dossier-all не принимает аргументов"
                exit 1
            fi
            show_dossier_all
            ;;

        *)
            printf "%s\n" "Ошибка: Неизвестный флаг '$1'"
            printf "%s\n" "Используйте --help для справки"
            exit 1
            ;;
    esac
}

# Запуск главной функции
main "$@"
