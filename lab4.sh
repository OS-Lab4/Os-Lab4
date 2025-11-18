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

ФОРМАТ НОМЕРА ГРУППЫ:
  A-XX-XX или Ae-XX-XX (например: A-06-04, Ae-21-22)

ПРИМЕРЫ:
  ./lab4.sh --best-grades A-06-04
  ./lab4.sh --performance Ae-21-22

EOF
}

# ==================== ВАЛИДАЦИЯ ====================

validate_group() {
    local group="$1"

    # Проверка формата группы
    if ! [[ "$group" =~ ^(A|Ae)-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Ошибка: Номер группы не соответствует формату (A-XX-XX или Ae-XX-XX)"
        exit 1
    fi

    # Проверка существования файла группы
    if [[ ! -f "$GROUPS_DIR/$group" ]]; then
        echo "Ошибка: Группа '$group' не существует"
        echo "Доступные группы:"
        ls "$GROUPS_DIR" | head -10
        exit 1
    fi

    # Проверка прав на чтение
    if [[ ! -r "$GROUPS_DIR/$group" ]]; then
        echo "Ошибка: Нет прав на чтение файла группы '$group'"
        exit 1
    fi
}

# ==================== ОСНОВНЫЕ ФУНКЦИИ ====================

# Функция для подсчёта количества оценок по каждому типу
count_grades() {
    local group="$1"

    echo ""
    echo "=========================================="
    echo "Анализ оценок для группы '$group'"
    echo "=========================================="
    echo ""

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
        echo "$student|$count_3|$count_4|$count_5" >> "$temp_file"
    done < "$GROUPS_DIR/$group"

    # Находим студентов с максимальным количеством троек, четвёрок и пятёрок
    local best_3=$(sort -t'|' -k2 -rn "$temp_file" | head -1)
    local best_4=$(sort -t'|' -k3 -rn "$temp_file" | head -1)
    local best_5=$(sort -t'|' -k4 -rn "$temp_file" | head -1)

    # Вывод таблицы для троек
    echo "Максимальное количество оценок 3"
    printf "%-32s | %-21s | %-17s | %-17s | %-s\n"  "Студент" "Группа" "Кол-во 3" "Кол-во 4" "Кол-во 5"
    echo "--------------------------------------------------------------------------------------------"
    if [[ -n "$best_3" ]]; then
        IFS='|' read -r student c3 c4 c5 <<< "$best_3"
        printf "%-25s | %-15s | %-12s | %-12s | %-12s\n" "$student" "$group" "$c3" "$c4" "$c5"
    fi
    echo ""

    # Вывод таблицы для четвёрок
    echo "Максимальное количество оценок 4"
    printf "%-32s | %-21s | %-17s | %-17s | %-s\n"  "Студент" "Группа" "Кол-во 3" "Кол-во 4" "Кол-во 5"
    echo "--------------------------------------------------------------------------------------------"
    if [[ -n "$best_4" ]]; then
        IFS='|' read -r student c3 c4 c5 <<< "$best_4"
        printf "%-25s | %-15s | %-12s | %-12s | %-12s\n" "$student" "$group" "$c3" "$c4" "$c5"
    fi
    echo ""

    # Вывод таблицы для пятёрок
    echo "Максимальное количество оценок 5"
    printf "%-32s | %-21s | %-17s | %-17s | %-s\n"  "Студент" "Группа" "Кол-во 3" "Кол-во 4" "Кол-во 5"
    echo "--------------------------------------------------------------------------------------------"
    if [[ -n "$best_5" ]]; then
        IFS='|' read -r student c3 c4 c5 <<< "$best_5"
        printf "%-25s | %-15s | %-12s | %-12s | %-12s\n" "$student" "$group" "$c3" "$c4" "$c5"
    fi
    echo ""

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

    echo "=========================================="
    echo "Сводная таблица с успеваемостью для группы '$group'"
    echo "=========================================="
    echo ""

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
        echo "$student|$pop_avg|$circus_avg|$overall_avg" >> "$temp_file"
    done < "$GROUPS_DIR/$group"

    # Вывод таблицы
    # Вручную добавляем пробелы к кириллическим заголовкам для выравнивания
    printf "%-33s | %-44s | %-31s | %-s\n"  "Студент" "Поп-Культуроведение" "Цирковое дело" "Общее усреднённое"
    echo "-----------------------------------------------------------------------------------------------"

    # Сортируем по общему среднему баллу (по убыванию), затем по фамилии
    sort -t'|' -k4 -rn -k1 "$temp_file" | while IFS='|' read -r student pop_avg circus_avg overall_avg; do
        printf "%-26s | %-26s | %-19s | %-23s\n" "$student" "$pop_avg" "$circus_avg" "$overall_avg"
    done

    # Удаляем временный файл
    rm -f "$temp_file"
    echo ""
}

# ==================== ГЛАВНАЯ ЛОГИКА ====================

main() {
    # Проверка наличия аргументов
    if [[ $# -eq 0 ]]; then
        echo "Ошибка: Не указаны аргументы"
        echo "Используйте --help для справки"
        exit 1
    fi

    # Проверка существования базовой директории
    if [[ ! -d "$BASE_DIR" ]]; then
        echo "Ошибка: Директория '$BASE_DIR' не найдена"
        exit 1
    fi

    case "$1" in
        -h|--help)
            print_help
            ;;

        --best-grades)
            if [[ $# -ne 2 ]]; then
                echo "Ошибка: Неверное количество аргументов"
                echo "Использование: $0 --best-grades <группа>"
                exit 1
            fi
            validate_group "$2"
            count_grades "$2"
            ;;

        --performance)
            if [[ $# -ne 2 ]]; then
                echo "Ошибка: Неверное количество аргументов"
                echo "Использование: $0 --performance <группа>"
                exit 1
            fi
            validate_group "$2"
            show_performance "$2"
            ;;

        *)
            echo "Ошибка: Неизвестный флаг '$1'"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
}

# Запуск главной функции
main "$@"
