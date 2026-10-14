package com.zentrip.api;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
public class AdminController {
    private final JdbcTemplate jdbc;

    public AdminController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/dashboard")
    public Map<String, Object> dashboard(HttpServletRequest request) {
        requireAdminId(request);
        Map<String, Object> summary = jdbc.queryForMap("""
                SELECT
                    (SELECT COUNT(*) FROM users WHERE role = 'customer') AS customer_count,
                    (SELECT COUNT(*) FROM users
                        WHERE role = 'customer' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY))
                        AS new_customers_30d,
                    (SELECT COUNT(*) FROM bookings WHERE LOWER(status) <> 'cancelled')
                      + (SELECT COUNT(*) FROM trips WHERE LOWER(status) <> 'cancelled')
                      + (SELECT COUNT(*) FROM transfers WHERE LOWER(status) <> 'cancelled')
                        AS reservation_count,
                    (SELECT COUNT(*) FROM trips WHERE LOWER(status) <> 'cancelled')
                        AS flight_count,
                    (SELECT COUNT(*) FROM bookings WHERE LOWER(status) <> 'cancelled')
                        AS service_booking_count,
                    (SELECT COUNT(*) FROM transfers WHERE LOWER(status) <> 'cancelled')
                        AS transfer_count,
                    COALESCE((SELECT SUM(total_amount) FROM bookings
                        WHERE LOWER(status) <> 'cancelled'), 0)
                      + COALESCE((SELECT SUM(price) FROM trips
                        WHERE LOWER(status) <> 'cancelled'), 0)
                      + COALESCE((SELECT SUM(price) FROM transfers
                        WHERE LOWER(status) <> 'cancelled'), 0)
                        AS booked_value
                """);
        return Map.of(
                "summary", summary,
                "recent_reservations", recentReservations(8));
    }

    @GetMapping("/reservations")
    public Map<String, Object> reservations(
            @RequestParam(defaultValue = "50") int limit,
            HttpServletRequest request) {
        requireAdminId(request);
        validateLimit(limit);
        return Map.of("reservations", recentReservations(limit));
    }

    @GetMapping("/customers")
    public Map<String, Object> customers(
            @RequestParam(defaultValue = "50") int limit,
            HttpServletRequest request) {
        requireAdminId(request);
        validateLimit(limit);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT u.id, u.name, u.email, u.phone, u.created_at,
                    (SELECT COUNT(*) FROM bookings b WHERE b.user_id = u.id)
                      + (SELECT COUNT(*) FROM trips t WHERE t.user_id = u.id)
                      + (SELECT COUNT(*) FROM transfers x WHERE x.user_id = u.id)
                      AS reservation_count
                FROM users u
                WHERE u.role = 'customer'
                ORDER BY u.created_at DESC
                LIMIT ?
                """, limit);
        return Map.of("customers", rows);
    }

    private List<Map<String, Object>> recentReservations(int limit) {
        return jdbc.queryForList("""
                SELECT *
                FROM (
                    SELECT CONCAT('flight-', t.id) AS id, 'Flight' AS type,
                        t.title, u.name AS customer_name,
                        COALESCE(t.departure_date, t.created_at) AS reservation_date,
                        COALESCE(t.price, 0) AS amount, t.status, t.created_at
                    FROM trips t JOIN users u ON u.id = t.user_id
                    UNION ALL
                    SELECT CONCAT('booking-', b.id) AS id, b.type,
                        COALESCE(b.title, b.subtitle, 'Booking') AS title,
                        u.name AS customer_name,
                        COALESCE(b.date, b.created_at) AS reservation_date,
                        COALESCE(b.total_amount, b.price, 0) AS amount,
                        b.status, b.created_at
                    FROM bookings b JOIN users u ON u.id = b.user_id
                    UNION ALL
                    SELECT CONCAT('transfer-', x.id) AS id, 'Transfer' AS type,
                        CONCAT(x.pickup_location, ' to ', x.dropoff_location) AS title,
                        u.name AS customer_name, x.pickup_time AS reservation_date,
                        x.price AS amount, x.status, x.created_at
                    FROM transfers x JOIN users u ON u.id = x.user_id
                ) reservations
                ORDER BY created_at DESC
                LIMIT ?
                """, limit);
    }

    private static void validateLimit(int limit) {
        if (limit < 1 || limit > 100) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "limit must be between 1 and 100");
        }
    }

    private long requireAdminId(HttpServletRequest request) {
        Object userId = request.getAttribute("authUserId");
        if (!(userId instanceof Number number)) {
            throw new ResponseStatusException(
                    HttpStatus.UNAUTHORIZED, "Unauthenticated");
        }
        String role = jdbc.queryForObject(
                "SELECT role FROM users WHERE id = ?",
                String.class,
                number.longValue());
        if (!"admin".equalsIgnoreCase(role)) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Administrator access required");
        }
        return number.longValue();
    }
}
