package com.zentrip.api;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCreator;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;
import org.springframework.web.util.UriComponentsBuilder;

import jakarta.servlet.http.HttpServletRequest;

@RestController
@RequestMapping("/api")
public class ApiController {
    private final JdbcTemplate jdbc;
    private final ProfilePhotoStorage profilePhotoStorage;
    private final PasswordEncoder passwords = new BCryptPasswordEncoder();
    private final RestClient http = RestClient.create();
    private final String serpApiKey;
    private static final ObjectMapper JSON = new ObjectMapper();

    public ApiController(JdbcTemplate jdbc,
                         @Value("${serpapi.key:}") String serpApiKey,
                         ProfilePhotoStorage profilePhotoStorage) {
        this.jdbc = jdbc;
        this.serpApiKey = serpApiKey;
        this.profilePhotoStorage = profilePhotoStorage;
    }

    @PostMapping("/auth/register")
    public ResponseEntity<?> register(@RequestParam String name,
                                      @RequestParam String email,
                                      @RequestParam String phone,
                                      @RequestParam String password,
                                      @RequestParam("password_confirmation") String confirmation,
                                      @RequestParam(value = "photo", required = false) MultipartFile photo,
                                      HttpServletRequest request) {
        if (name.isBlank() || !email.contains("@") || password.length() < 8 || !password.equals(confirmation)) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Invalid registration details");
        }
        if (jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE email = ?", Integer.class, email) > 0) {
            return ResponseEntity.unprocessableEntity().body(validationError(
                    "email", "The email has already been taken."));
        }
        String photoUrl = profilePhotoStorage.store(photo);
        long id = insert("INSERT INTO users (name, email, phone, password, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())",
                name, email, phone, passwords.encode(password));
        if (photoUrl != null) saveProfilePhotoUrl(id, photoUrl);
        return ResponseEntity.status(HttpStatus.CREATED).body(authPayload(id, request));
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        String email = text(body.get("email"));
        String password = text(body.get("password"));
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT id, password FROM users WHERE email = ?", email);
        if (rows.isEmpty() || !passwords.matches(password, text(rows.getFirst().get("password")))) {
            return ResponseEntity.unprocessableEntity().body(validationError(
                    "email", "The provided credentials are incorrect."));
        }
        return ResponseEntity.ok(authPayload(number(rows.getFirst().get("id")), request));
    }

    @GetMapping("/auth/me")
    public Map<String, Object> me(HttpServletRequest request) {
        long userId = requireUserId(request);
        return Map.of("user", userPayload(userId, request));
    }

    @PostMapping("/profile")
    public ResponseEntity<?> updateProfile(
            @RequestParam(value = "name", required = false) String name,
            @RequestParam(value = "phone", required = false) String phone,
            @RequestParam(value = "photo", required = false) MultipartFile photo,
            HttpServletRequest request) {
        long userId = requireUserId(request);
        String normalizedName = text(name).trim();
        String normalizedPhone = text(phone).trim();
        if (normalizedName.isBlank() || normalizedName.length() > 255) {
            return ResponseEntity.unprocessableEntity().body(validationError("name", "The name field is required and must not exceed 255 characters."));
        }
        if (normalizedPhone.isBlank() || normalizedPhone.length() > 20) {
            return ResponseEntity.unprocessableEntity().body(validationError("phone", "The phone field is required and must not exceed 20 characters."));
        }

        String photoUrl = profilePhotoStorage.store(photo);
        jdbc.update("UPDATE users SET name = ?, phone = ?, updated_at = NOW() WHERE id = ?",
                normalizedName, normalizedPhone, userId);
        if (photoUrl != null) saveProfilePhotoUrl(userId, photoUrl);
        return ResponseEntity.ok(Map.of("user", userPayload(userId, request)));
    }

    @PutMapping("/profile/password")
    public ResponseEntity<?> changePassword(
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        long userId = requireUserId(request);
        String currentPassword = text(body.get("current_password"));
        String newPassword = text(body.get("password"));
        String confirmation = text(body.get("password_confirmation"));
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT password FROM users WHERE id = ?", userId);
        if (rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        if (!passwords.matches(currentPassword, text(rows.getFirst().get("password")))) {
            return ResponseEntity.unprocessableEntity().body(validationError(
                    "current_password", "The current password is incorrect."));
        }
        if (newPassword.length() < 8) {
            return ResponseEntity.unprocessableEntity().body(validationError(
                    "password", "The password must be at least 8 characters."));
        }
        if (!newPassword.equals(confirmation)) {
            return ResponseEntity.unprocessableEntity().body(validationError(
                    "password", "The password confirmation does not match."));
        }

        jdbc.update("UPDATE users SET password = ?, updated_at = NOW() WHERE id = ?",
                passwords.encode(newPassword), userId);
        String currentTokenHash = (String) request.getAttribute("authTokenHash");
        if (currentTokenHash != null) {
            jdbc.update("DELETE FROM api_tokens WHERE user_id = ? AND token_hash <> ?", userId, currentTokenHash);
        }
        return ResponseEntity.ok(Map.of("message", "Password updated successfully"));
    }

    @PostMapping("/auth/logout")
    public Map<String, String> logout(HttpServletRequest request) {
        String tokenHash = (String) request.getAttribute("authTokenHash");
        requireUserId(request);
        jdbc.update("DELETE FROM api_tokens WHERE token_hash = ?", tokenHash);
        return Map.of("message", "Logged out successfully");
    }

    @GetMapping("/offers")
    public Map<String, Object> offers() {
        List<Map<String, Object>> payload = jdbc.queryForList("""
                SELECT id, title, location, country, destination_code, description,
                       image_url, price_per_person, flight_price_per_person,
                       hotel_price_per_night, duration_nights, rating, review_count,
                       highlights, is_featured, category
                FROM offers WHERE is_active = TRUE
                ORDER BY is_featured DESC, sort_order ASC, title ASC
                """).stream().map(row -> {
                    Map<String, Object> offer = new LinkedHashMap<>(row);
                    offer.put("highlights", parseHighlights(row.get("highlights")));
                    return offer;
                }).toList();
        return Map.of("offers", payload);
    }

    private static List<String> parseHighlights(Object raw) {
        if (raw instanceof List<?> list) {
            return list.stream().map(Object::toString).toList();
        }
        if (raw == null) return List.of();
        try {
            return JSON.readValue(raw.toString(), new TypeReference<List<String>>() {});
        } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
            return List.of();
        }
    }

    @GetMapping("/trips")
    public Map<String, Object> trips(HttpServletRequest request) {
        long userId = requireUserId(request);
        List<Map<String, Object>> rows = jdbc.queryForList("""
            SELECT trips.*,
                  JSON_UNQUOTE(JSON_EXTRACT(details, '$.arrival_date')) AS arrival_date,
                  JSON_UNQUOTE(JSON_EXTRACT(details, '$.refund_status')) AS refund_status,
                  JSON_UNQUOTE(JSON_EXTRACT(details, '$.refund_method')) AS refund_method
            FROM trips WHERE user_id = ? ORDER BY created_at DESC
            """, userId);
        return Map.of("trips", rows);
    }

    @PostMapping("/trips")
    @Transactional
    public ResponseEntity<?> createTrip(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        long userId = requireUserId(request);
        String originCode = required(body, "origin_code");
        String originCity = required(body, "origin_city");
        String destinationCode = required(body, "destination_code");
        String destinationCity = required(body, "destination_city");
        LocalDateTime departure = flightDateTime(required(body, "departure_date"));
        LocalDateTime arrival = flightDateTime(required(body, "arrival_date"));
        LocalDateTime returnDate = nullableFlightDateTime(body.get("return_date"));
        if (!arrival.isAfter(departure)) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY, "arrival_date must be after departure_date");
        }
        if (returnDate != null && returnDate.isBefore(departure)) {
            throw new ResponseStatusException(
                HttpStatus.UNPROCESSABLE_ENTITY, "return_date must not be before departure_date");
        }
        String flightNumber = required(body, "flight_number");
        PartnerListingAttribution attribution =
                partnerListingAttribution(body.get("partner_listing_id"), "flight");
        BigDecimal price = partnerBookingPrice(
                attribution, "flight", departure, arrival, decimal(body.get("price")));
        jdbc.queryForList("SELECT id FROM users WHERE id = ? FOR UPDATE", userId);
        if (hasFlightScheduleConflict(userId, departure, arrival, returnDate)) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("message", "FLIGHT_SCHEDULE_CONFLICT"));
        }
        long id = insert("""
                INSERT INTO trips (user_id, partner_id, partner_listing_id, title, destination, origin_code, origin_city, destination_code,
                destination_city, departure_date, return_date, flight_number, airline, airline_logo_url,
                is_direct, seat_class, price, booking_ref, status, details, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, JSON_OBJECT('arrival_date', ?), NOW(), NOW())
                """, userId, attribution.partnerId(), attribution.listingId(),
                originCity + " to " + destinationCity, destinationCity, originCode, originCity,
                destinationCode, destinationCity, Timestamp.valueOf(departure),
                returnDate == null ? null : Timestamp.valueOf(returnDate),
                flightNumber, body.get("airline"), body.get("airline_logo_url"), bool(body.get("is_direct"), true),
                value(body, "seat_class", "Economy"), price, body.get("booking_ref"),
                "upcoming", arrival.toString());
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("trip", tripRow(id)));
    }

    @GetMapping("/trips/availability")
    public Map<String, Object> flightAvailability(
            @RequestParam("departure_date") String departureValue,
            @RequestParam("arrival_date") String arrivalValue,
            @RequestParam(value = "return_date", required = false) String returnValue,
            HttpServletRequest request) {
        long userId = requireUserId(request);
        LocalDateTime departure = flightDateTime(departureValue);
        LocalDateTime arrival = flightDateTime(arrivalValue);
        LocalDateTime returnDate = nullableFlightDateTime(returnValue);
        if (!arrival.isAfter(departure)) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY, "arrival_date must be after departure_date");
        }
        if (returnDate != null && returnDate.isBefore(departure)) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY, "return_date must not be before departure_date");
        }
        return Map.of("available",
                !hasFlightScheduleConflict(userId, departure, arrival, returnDate));
    }

    private boolean hasFlightScheduleConflict(
            long userId,
            LocalDateTime departure,
            LocalDateTime arrival,
            LocalDateTime returnDate) {
        LocalDate requestedStart = departure.toLocalDate();
        LocalDate requestedEnd = tripLastOccupiedDate(departure, arrival, returnDate);
        List<Map<String, Object>> trips = jdbc.queryForList("""
                SELECT departure_date, return_date, status,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.arrival_date')) AS arrival_date
                FROM trips
                WHERE user_id = ? AND LOWER(status) NOT IN ('cancelled', 'completed')
                """, userId);

        for (Map<String, Object> trip : trips) {
            LocalDateTime existingDeparture = storedFlightDateTime(trip.get("departure_date"));
            if (existingDeparture == null) continue;
            LocalDateTime existingArrival = storedFlightDateTime(trip.get("arrival_date"));
            LocalDateTime existingReturn = storedFlightDateTime(trip.get("return_date"));
            LocalDate existingStart = existingDeparture.toLocalDate();
            LocalDate existingEnd = tripLastOccupiedDate(
                    existingDeparture, existingArrival, existingReturn);
            if (!existingStart.isAfter(requestedEnd)
                    && !requestedStart.isAfter(existingEnd)) {
                return true;
            }
        }
        return false;
    }

    private static LocalDate tripLastOccupiedDate(
            LocalDateTime departure, LocalDateTime arrival, LocalDateTime returnDate) {
        LocalDate end = departure.toLocalDate();
        if (arrival != null && arrival.toLocalDate().isAfter(end)) {
            end = arrival.toLocalDate();
        }
        if (returnDate != null && returnDate.toLocalDate().isAfter(end)) {
            end = returnDate.toLocalDate();
        }
        return end;
    }

    private static LocalDateTime nullableFlightDateTime(Object value) {
        return value == null || text(value).isBlank() ? null : flightDateTime(text(value));
    }

    private static LocalDateTime storedFlightDateTime(Object value) {
        if (value instanceof Timestamp timestamp) return timestamp.toLocalDateTime();
        if (value instanceof LocalDateTime dateTime) return dateTime;
        if (value instanceof java.sql.Date date) return date.toLocalDate().atStartOfDay();
        if (value == null || text(value).isBlank()) return null;
        try {
            return flightDateTime(text(value));
        } catch (ResponseStatusException exception) {
            return null;
        }
    }

    private Map<String, Object> tripRow(long id) {
        return jdbc.queryForMap("""
                SELECT trips.*,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.arrival_date')) AS arrival_date,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.refund_status')) AS refund_status,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.refund_method')) AS refund_method
                FROM trips WHERE id = ?
                """, id);
    }

    @DeleteMapping("/trips/{id}")
    @Transactional
    public ResponseEntity<?> deleteTrip(@PathVariable long id, HttpServletRequest request) {
        long userId = requireUserId(request);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, status,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.refund_status')) AS refund_status,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.refund_method')) AS refund_method
                FROM trips WHERE id = ? AND user_id = ? FOR UPDATE
                """, id, userId);
        if (rows.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);

        Map<String, Object> trip = rows.getFirst();
        String status = value(trip.get("status"), "upcoming");
        boolean alreadyCancelled = "cancelled".equalsIgnoreCase(status);
        if (!alreadyCancelled) {
            int updated = jdbc.update("""
                    UPDATE trips
                    SET status = 'cancelled',
                        details = JSON_SET(COALESCE(details, JSON_OBJECT()),
                            '$.refund_status', 'pending_airline_review',
                            '$.refund_method', 'original_payment_method',
                            '$.refund_requested_at', UTC_TIMESTAMP()),
                        updated_at = NOW()
                    WHERE id = ? AND user_id = ?
                    """, id, userId);
            if (updated == 0) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }

        return ResponseEntity.ok(Map.of(
                "status", "cancelled",
            "refund_status", alreadyCancelled
                ? value(trip.get("refund_status"), "pending_airline_review")
                : "pending_airline_review",
            "refund_method", alreadyCancelled
                ? value(trip.get("refund_method"), "original_payment_method")
                : "original_payment_method"));
    }

    @GetMapping("/bookings")
    public Map<String, Object> bookings(HttpServletRequest request) {
        long userId = requireUserId(request);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT bookings.*,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.end_date')) AS end_date,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.image_url')) AS image_url
                FROM bookings WHERE user_id = ? ORDER BY created_at DESC
                """, userId);
        List<Map<String, Object>> payload = rows.stream().map(this::bookingPayload).toList();
        return Map.of("bookings", payload);
    }

    @GetMapping("/bookings/availability")
    public Map<String, Object> bookingAvailability(
            @RequestParam String type,
            @RequestParam String title,
            @RequestParam("start_date") String startValue,
            @RequestParam("end_date") String endValue,
            HttpServletRequest request) {
        long userId = requireUserId(request);
        String normalizedType = supportedBookingType(type);
        LocalDateTime start = flightDateTime(startValue);
        LocalDateTime end = flightDateTime(endValue);
        if (!end.isAfter(start)) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY, "end_date must be after start_date");
        }
        return Map.of("available", !hasBookingScheduleConflict(
                userId, normalizedType, title, start, end));
    }

    @PostMapping("/bookings")
    @Transactional
    public ResponseEntity<?> createBooking(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        long userId = requireUserId(request);
        String type = supportedBookingType(required(body, "type"));
        String title = required(body, "title");
        String subtitle = required(body, "subtitle");
        LocalDateTime start = flightDateTime(required(body, "date"));
        LocalDateTime end = nullableFlightDateTime(body.get("end_date"));
        if (end == null) end = start.plusDays(1);
        if (!end.isAfter(start)) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY, "end_date must be after start_date");
        }
        BigDecimal price = decimal(body.get("price"));
        PartnerListingAttribution attribution =
                partnerListingAttribution(body.get("partner_listing_id"), type);
        price = partnerBookingPrice(attribution, type, start, end, price);
        jdbc.queryForList("SELECT id FROM users WHERE id = ? FOR UPDATE", userId);
        if (hasBookingScheduleConflict(userId, type, title, start, end)) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("message", "BOOKING_SCHEDULE_CONFLICT"));
        }
        long id = insert("""
                INSERT INTO bookings (user_id, partner_id, partner_listing_id, type, status, total_amount, title, subtitle, `date`, price, ref_code, details, created_at, updated_at)
                VALUES (?, ?, ?, ?, 'upcoming', ?, ?, ?, ?, ?, ?, CAST(? AS JSON), NOW(), NOW())
                """, userId, attribution.partnerId(), attribution.listingId(),
                type, price, title, subtitle,
                Timestamp.valueOf(start), price, body.get("ref_code"),
                bookingDetailsJson(end, body.get("image_url")));
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("booking", bookingPayload(jdbc.queryForMap("""
                        SELECT bookings.*,
                               JSON_UNQUOTE(JSON_EXTRACT(details, '$.end_date')) AS end_date,
                               JSON_UNQUOTE(JSON_EXTRACT(details, '$.image_url')) AS image_url
                        FROM bookings WHERE id = ?
                        """, id))));
    }

    @DeleteMapping("/bookings/{id}")
    @Transactional
    public ResponseEntity<?> cancelBooking(
            @PathVariable long id, HttpServletRequest request) {
        long userId = requireUserId(request);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT status FROM bookings
                WHERE id = ? AND user_id = ?
                FOR UPDATE
                """, id, userId);
        if (rows.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Booking not found");
        }

        String status = text(rows.getFirst().get("status")).toLowerCase();
        if ("completed".equals(status)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Completed bookings cannot be cancelled");
        }
        if (!"cancelled".equals(status)) {
            jdbc.update("""
                    UPDATE bookings SET status = 'cancelled', updated_at = NOW()
                    WHERE id = ? AND user_id = ?
                    """, id, userId);
        }
        return ResponseEntity.ok(Map.of("status", "cancelled"));
    }

    /** JSON stored in bookings.details: end date plus an optional http(s) cover image. */
    static String bookingDetailsJson(LocalDateTime end, Object imageUrl) {
        Map<String, Object> details = new LinkedHashMap<>();
        details.put("end_date", end.toString());
        if (imageUrl instanceof String url) {
            String trimmed = url.trim();
            boolean safe = trimmed.length() <= 2048
                    && (trimmed.startsWith("https://") || trimmed.startsWith("http://"));
            if (safe) details.put("image_url", trimmed);
        }
        try {
            return JSON.writeValueAsString(details);
        } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
            throw new IllegalStateException("Could not serialize booking details", exception);
        }
    }

    private String supportedBookingType(String type) {
        String normalized = type.toLowerCase();
        if (!List.of("hotel", "car", "attraction", "package").contains(normalized)) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "Booking type must be hotel, car, attraction, or package");
        }
        return normalized;
    }

    private boolean hasBookingScheduleConflict(
            long userId, String type, String title, LocalDateTime start, LocalDateTime end) {
        List<Map<String, Object>> existingBookings = jdbc.queryForList("""
                SELECT title, `date`,
                       JSON_UNQUOTE(JSON_EXTRACT(details, '$.end_date')) AS end_date
                FROM bookings
                WHERE user_id = ? AND LOWER(type) = ?
                  AND LOWER(status) NOT IN ('cancelled', 'completed')
                """, userId, type);

        for (Map<String, Object> existing : existingBookings) {
            if ("attraction".equals(type)
                    && !text(existing.get("title")).equalsIgnoreCase(title)) {
                continue;
            }
            LocalDateTime existingStart = storedFlightDateTime(existing.get("date"));
            if (existingStart == null) continue;
            LocalDateTime existingEnd = storedFlightDateTime(existing.get("end_date"));
            if (existingEnd == null) existingEnd = existingStart.plusDays(1);
            if (existingStart.isBefore(end) && start.isBefore(existingEnd)) return true;
        }
        return false;
    }

    @GetMapping("/transfers")
    public Map<String, Object> transfers(HttpServletRequest request) {
        long userId = requireUserId(request);
        return Map.of("transfers", jdbc.queryForList("""
                SELECT transfers.*,
                       COALESCE(transfer_schedules.duration_minutes, 60) AS duration_minutes
                FROM transfers
                LEFT JOIN transfer_schedules ON transfer_schedules.transfer_id = transfers.id
                WHERE transfers.user_id = ?
                ORDER BY transfers.created_at DESC
                """, userId));
    }

    @GetMapping("/transfers/availability")
    public Map<String, Object> transferAvailability(
            @RequestParam("pickup_time") String pickupValue,
            @RequestParam("duration_minutes") int durationMinutes,
            HttpServletRequest request) {
        long userId = requireUserId(request);
        validateTransferDuration(durationMinutes);
        LocalDateTime pickupTime = dateTime(pickupValue).toLocalDateTime();
        return Map.of("available",
                !hasTransferScheduleConflict(userId, pickupTime, durationMinutes));
    }

    @PostMapping("/transfers")
    @Transactional
    public ResponseEntity<?> createTransfer(
            @RequestBody Map<String, Object> body, HttpServletRequest request) {
        long userId = requireUserId(request);
        LocalDateTime pickupTime = dateTime(required(body, "pickup_time")).toLocalDateTime();
        int durationMinutes = integer(body.get("duration_minutes"), 0);
        validateTransferDuration(durationMinutes);
        PartnerListingAttribution attribution =
                partnerListingAttribution(body.get("partner_listing_id"), "transfer");
        BigDecimal price = partnerBookingPrice(
                attribution,
                "transfer",
                pickupTime,
                pickupTime.plusMinutes(durationMinutes),
                decimal(body.get("price")));
        jdbc.queryForList("SELECT id FROM users WHERE id = ? FOR UPDATE", userId);
        if (hasTransferScheduleConflict(userId, pickupTime, durationMinutes)) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("message", "TAXI_SCHEDULE_CONFLICT"));
        }
        long id = insert("""
                INSERT INTO transfers (user_id, partner_id, partner_listing_id, provider_name, vehicle_type, pickup_location, dropoff_location,
                pickup_time, price, passengers, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                """, userId, attribution.partnerId(), attribution.listingId(),
                required(body, "provider_name"), required(body, "vehicle_type"),
                required(body, "pickup_location"), required(body, "dropoff_location"),
                Timestamp.valueOf(pickupTime), price,
                integer(body.get("passengers"), 1), value(body, "status", "confirmed"));
        jdbc.update(
                "INSERT INTO transfer_schedules (transfer_id, duration_minutes) VALUES (?, ?)",
                id, durationMinutes);
        Map<String, Object> transfer = jdbc.queryForMap("SELECT * FROM transfers WHERE id = ?", id);
        transfer.put("id", Long.toString(id));
        transfer.put("duration_minutes", durationMinutes);
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("transfer", transfer));
    }

    private boolean hasTransferScheduleConflict(
            long userId, LocalDateTime pickupTime, int durationMinutes) {
        LocalDateTime requestedEnd = pickupTime.plusMinutes(durationMinutes);
        List<Map<String, Object>> transfers = jdbc.queryForList("""
                SELECT transfers.pickup_time, transfers.status,
                       COALESCE(transfer_schedules.duration_minutes, 60) AS duration_minutes
                FROM transfers
                LEFT JOIN transfer_schedules ON transfer_schedules.transfer_id = transfers.id
                WHERE transfers.user_id = ?
                  AND LOWER(transfers.status) NOT IN ('cancelled', 'completed')
                """, userId);

        for (Map<String, Object> transfer : transfers) {
            LocalDateTime existingStart =
                    storedFlightDateTime(transfer.get("pickup_time"));
            if (existingStart == null) continue;
            int existingDuration = integer(transfer.get("duration_minutes"), 60);
            if (existingDuration < 1) existingDuration = 60;
            LocalDateTime existingEnd = existingStart.plusMinutes(existingDuration);
            if (existingStart.isBefore(requestedEnd)
                    && pickupTime.isBefore(existingEnd)) {
                return true;
            }
        }
        return false;
    }

    private static void validateTransferDuration(int durationMinutes) {
        if (durationMinutes < 1 || durationMinutes > 1440) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "duration_minutes must be between 1 and 1440");
        }
    }

    @PostMapping("/payments/checkout")
    public Map<String, Object> checkout(@RequestBody Map<String, Object> body) {
        required(body, "amount");
        String reference = value(body, "reference_id", UUID.randomUUID().toString());
        return Map.of("session_id", "mock_" + reference, "checkout_url", "mock://checkout");
    }

    @GetMapping("/payments/verify/{sessionId}")
    public Map<String, Object> verifyPayment(@PathVariable String sessionId) {
        return Map.of("paid", true, "session_id", sessionId);
    }

    @GetMapping("/maps/search")
    public Map<String, Object> mapsSearch(@RequestParam String query,
                                          @RequestParam double lat,
                                          @RequestParam double lng,
                                          @RequestParam(defaultValue = "attraction") String category,
                                          @RequestParam(defaultValue = "10") int limit,
                                          HttpServletRequest request) {
        requireUserId(request);
        if (serpApiKey.isBlank()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "SERPAPI_KEY is not configured");
        String url = UriComponentsBuilder.fromUriString("https://serpapi.com/search.json")
                .queryParam("engine", "google_maps").queryParam("q", query)
                .queryParam("ll", "@" + lat + "," + lng + ",14z")
                .queryParam("nearby", "true").queryParam("num", Math.min(Math.max(limit, 1), 20))
                .queryParam("api_key", serpApiKey).build().encode().toUriString();
        Map<?, ?> response = http.get().uri(url).retrieve().body(Map.class);
        List<?> source = response != null && response.get("local_results") instanceof List<?> list ? list : List.of();
        List<Map<String, Object>> results = new ArrayList<>();
        for (Object item : source) {
            if (!(item instanceof Map<?, ?> place)) continue;
            Map<?, ?> coordinates = place.get("gps_coordinates") instanceof Map<?, ?> c ? c : Map.of();
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("title", value(place.get("title"), ""));
            result.put("address", value(place.get("address"), ""));
            result.put("category", category);
            result.put("place_id", place.get("place_id"));
            result.put("rating", place.get("rating"));
            result.put("reviews", place.get("reviews"));
            result.put("phone", place.get("phone"));
            result.put("website", place.get("website"));
            result.put("latitude", coordinates.get("latitude"));
            result.put("longitude", coordinates.get("longitude"));
            result.put("type", place.get("type"));
            result.put("thumbnail", place.get("thumbnail"));
            results.add(result);
        }
        return Map.of("results", results);
    }

    private Map<String, Object> authPayload(long userId, HttpServletRequest request) {
        String token = UUID.randomUUID().toString().replace("-", "") + UUID.randomUUID().toString().replace("-", "");
        jdbc.update("INSERT INTO api_tokens (user_id, token_hash, expires_at) VALUES (?, ?, ?)",
                userId, TokenAuthFilter.sha256(token), Timestamp.from(Instant.now().plusSeconds(60L * 60 * 24 * 30)));
        return Map.of("user", userPayload(userId, request), "token", token);
    }

    private Map<String, Object> userPayload(long userId, HttpServletRequest request) {
        Map<String, Object> user = jdbc.queryForMap("""
                SELECT u.id, u.name, u.email, u.phone, u.role,
                       u.partner_id, partners.name AS partner_name,
                       partners.service_type AS partner_service_type, p.photo_url
                FROM users u
                LEFT JOIN partners ON partners.id = u.partner_id
                LEFT JOIN user_profiles p ON p.user_id = u.id
                WHERE u.id = ?
                """, userId);
        user.put("id", number(user.get("id")));
        String photoUrl = text(user.get("photo_url"));
        if (!photoUrl.isBlank()) {
            user.put("photo_url", ServletUriComponentsBuilder.fromRequestUri(request)
                    .replacePath(photoUrl)
                    .replaceQuery(null)
                    .build()
                    .toUriString());
        }
        return user;
    }

    private void saveProfilePhotoUrl(long userId, String photoUrl) {
        jdbc.update("""
                INSERT INTO user_profiles (user_id, photo_url, created_at, updated_at)
                VALUES (?, ?, NOW(), NOW())
                ON DUPLICATE KEY UPDATE photo_url = ?, updated_at = NOW()
                """, userId, photoUrl, photoUrl);
    }

    private Map<String, Object> bookingPayload(Map<String, Object> row) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", Long.toString(number(row.get("id"))));
        result.put("type", row.get("type"));
        result.put("title", value(row.get("title"), ""));
        result.put("subtitle", value(row.get("subtitle"), ""));
        result.put("date", row.get("date") == null ? null : row.get("date").toString());
        result.put("end_date", row.get("end_date") == null ? null : row.get("end_date").toString());
        result.put("price", row.get("price"));
        result.put("ref_code", row.get("ref_code"));
        result.put("image_url", row.get("image_url"));
        result.put("status", value(row.get("status"), "upcoming"));
        return result;
    }

    private PartnerListingAttribution partnerListingAttribution(
            Object rawListingId, String requestedType) {
        if (rawListingId == null || text(rawListingId).isBlank()) {
            return new PartnerListingAttribution(null, null, null);
        }
        long listingId;
        try {
            listingId = Long.parseLong(text(rawListingId));
        } catch (NumberFormatException exception) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY, "Invalid partner listing");
        }
        List<Map<String, Object>> listings = jdbc.queryForList("""
                SELECT l.id, l.partner_id, l.type, l.active, l.price
                FROM partner_listings l
                JOIN partners p ON p.id = l.partner_id AND p.status = 'active'
                WHERE l.id = ?
                """, listingId);
        if (listings.isEmpty()) {
            throw new ResponseStatusException(
                    HttpStatus.NOT_FOUND, "Partner listing not found");
        }
        Map<String, Object> listing = listings.getFirst();
        if (!bool(listing.get("active"), false)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "Partner listing is not available");
        }
        String listingType = text(listing.get("type"));
        boolean typeMatches = switch (requestedType) {
            case "flight" -> "flight".equals(listingType);
            case "hotel", "car", "attraction", "package" ->
                    requestedType.equals(listingType);
            case "transfer" -> "transfer".equals(listingType);
            default -> false;
        };
        if (!typeMatches) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "Partner listing does not match the reservation type");
        }
        return new PartnerListingAttribution(
                number(listing.get("partner_id")),
                number(listing.get("id")),
                decimal(listing.get("price")));
    }

    private BigDecimal partnerBookingPrice(
            PartnerListingAttribution attribution,
            String type,
            LocalDateTime start,
            LocalDateTime end,
            BigDecimal clientPrice) {
        if (attribution.listingId() == null) return clientPrice;
        long days = Math.max(1, java.time.temporal.ChronoUnit.DAYS.between(
                start.toLocalDate(), end.toLocalDate()));
        BigDecimal price = switch (type) {
            case "flight" -> attribution.price()
                    .multiply(new BigDecimal("1.12"))
                    .add(new BigDecimal("12"));
            case "hotel" -> attribution.price()
                    .multiply(BigDecimal.valueOf(days))
                    .multiply(new BigDecimal("1.12"));
            case "car" -> attribution.price().multiply(BigDecimal.valueOf(days));
            default -> attribution.price();
        };
        return price.setScale(2, RoundingMode.HALF_UP);
    }

    private record PartnerListingAttribution(
            Long partnerId, Long listingId, BigDecimal price) {}

    private long requireUserId(HttpServletRequest request) {
        Object userId = request.getAttribute("authUserId");
        if (!(userId instanceof Number number)) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthenticated");
        return number.longValue();
    }

    private long insert(String sql, Object... args) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update((PreparedStatementCreator) connection -> {
            PreparedStatement statement = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            for (int i = 0; i < args.length; i++) statement.setObject(i + 1, args[i]);
            return statement;
        }, keyHolder);
        Number key = keyHolder.getKey();
        if (key == null) throw new IllegalStateException("Insert did not return an ID");
        return key.longValue();
    }

    private static String required(Map<String, Object> body, String key) {
        String value = text(body.get(key));
        if (value.isBlank()) throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, key + " is required");
        return value;
    }

    private static Map<String, Object> validationError(String field, String message) {
        return Map.of(
                "message", "The given data was invalid.",
                "errors", Map.of(field, List.of(message)));
    }

    private static String text(Object value) {
        return value == null ? "" : value.toString();
    }

    private static String value(Map<String, Object> body, String key, String fallback) {
        return body.get(key) == null ? fallback : text(body.get(key));
    }

    private static String value(Object value, String fallback) {
        return value == null ? fallback : value.toString();
    }

    private static BigDecimal decimal(Object value) {
        if (value == null || text(value).isBlank()) return BigDecimal.ZERO;
        try {
            return new BigDecimal(text(value));
        } catch (NumberFormatException exception) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Invalid numeric value");
        }
    }

    private static int integer(Object value, int fallback) {
        if (value == null) return fallback;
        try {
            return Integer.parseInt(text(value));
        } catch (NumberFormatException exception) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Invalid integer value");
        }
    }

    private static boolean bool(Object value, boolean fallback) {
        if (value == null) return fallback;
        if (value instanceof Boolean flag) return flag;
        String text = value.toString().toLowerCase();
        return text.equals("true") || text.equals("1") || text.equals("yes");
    }

    private static long number(Object value) {
        return value instanceof Number number ? number.longValue() : Long.parseLong(text(value));
    }

    private static Timestamp dateTime(String value) {
        try {
            return Timestamp.valueOf(OffsetDateTime.parse(value).toLocalDateTime());
        } catch (DateTimeParseException ignored) {
            try {
                return Timestamp.valueOf(LocalDateTime.parse(value));
            } catch (DateTimeParseException exception) {
                return Timestamp.valueOf(LocalDate.parse(value).atStartOfDay());
            }
        }
    }

    private static LocalDateTime flightDateTime(String value) {
        try {
            return OffsetDateTime.parse(value)
                    .withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime();
        } catch (DateTimeParseException ignored) {
            try {
                return LocalDateTime.parse(value);
            } catch (DateTimeParseException ignoredLocalDateTime) {
                try {
                    return LocalDate.parse(value).atStartOfDay();
                } catch (DateTimeParseException invalidDate) {
                    throw new ResponseStatusException(
                            HttpStatus.UNPROCESSABLE_ENTITY, "Invalid flight schedule time");
                }
            }
        }
    }

    private static Timestamp nullableDateTime(Object value) {
        return value == null || text(value).isBlank() ? null : dateTime(text(value));
    }
}