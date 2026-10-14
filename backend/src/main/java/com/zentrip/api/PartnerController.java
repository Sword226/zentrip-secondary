package com.zentrip.api;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
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
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.sql.PreparedStatement;
import java.sql.Statement;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;

@RestController
@RequestMapping("/api")
public class PartnerController {
    private static final ObjectMapper JSON = new ObjectMapper();
    private static final List<String> LISTING_TYPES =
            List.of("flight", "hotel", "car", "attraction", "transfer", "package");
    private static final Map<String, LocationMetadata> LOCATIONS = Map.of(
            "Tripoli", new LocationMetadata("MJI", "Libya", "Western Libya"),
            "Misrata", new LocationMetadata("MRA", "Libya", "Central Libya"),
            "Benghazi", new LocationMetadata("BEN", "Libya", "Eastern Libya"),
            "Sebha", new LocationMetadata("SEB", "Libya", "Southern Libya"),
            "Cairo", new LocationMetadata("CAI", "Egypt", "North Africa"),
            "Tunis", new LocationMetadata("TUN", "Tunisia", "North Africa"),
            "Istanbul", new LocationMetadata("IST", "Turkiye", "Europe"),
            "Jeddah", new LocationMetadata("JED", "Saudi Arabia", "Middle East"),
            "Dubai", new LocationMetadata(
                    "DXB", "United Arab Emirates", "Middle East"));
    private final JdbcTemplate jdbc;

    public PartnerController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static LocationMetadata validateListingData(
            String type,
            String city,
            Map<String, Object> attributes) {
        LocationMetadata baseLocation;
        if ("flight".equals(type)) {
            LocationMetadata origin = validateAirport(
                    attributes, "origin_city", "origin_code");
            LocationMetadata destination = validateAirport(
                    attributes, "destination_city", "destination_code");
            validateKnownLocation(origin.city(), null);
            attributes.put("origin_country", origin.country());
            attributes.put("origin_region", origin.region());
            attributes.put("destination_country", destination.country());
            attributes.put("destination_region", destination.region());
            attributes.put("location_code", origin.code());
            attributes.put("location_region", origin.region());
            if (!city.trim().equalsIgnoreCase(
                    origin.city())) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "Listing city must match the flight origin");
            }
            baseLocation = origin;
        } else if ("transfer".equals(type)) {
            LocationMetadata pickup = validateKnownLocation(
                    text(attributes.get("pickup_location")), null);
            LocationMetadata dropoff = validateKnownLocation(
                    text(attributes.get("dropoff_location")), null);
            baseLocation = pickup;
            attributes.put("pickup_location", pickup.city());
            attributes.put("pickup_code", pickup.code());
            attributes.put("pickup_country", pickup.country());
            attributes.put("pickup_region", pickup.region());
            attributes.put("dropoff_location", dropoff.city());
            attributes.put("dropoff_code", dropoff.code());
            attributes.put("dropoff_country", dropoff.country());
            attributes.put("dropoff_region", dropoff.region());
            attributes.put("location_code", pickup.code());
            attributes.put("location_region", pickup.region());
            if (!city.trim().equalsIgnoreCase(
                    pickup.city())) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "Listing city must match the transfer pickup");
            }
        } else {
            LocationMetadata location = validateKnownLocation(city, null);
            baseLocation = location;
            attributes.put("location_code", location.code());
            attributes.put("location_region", location.region());
            if ("car".equals(type)) {
                attributes.put("pickup_location", location.city());
            }
        }
        Map<String, Set<String>> listFields = Map.of(
                "hotel", Set.of("amenities"),
                "car", Set.of("features"),
                "attraction", Set.of("tags"),
                "transfer", Set.of("included_services"),
                "package", Set.of("highlights"));
        for (String field : listFields.getOrDefault(type, Set.of())) {
            Object value = attributes.get(field);
            if (value != null && !(value instanceof List<?>)) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, field + " must be an array");
            }
        }
        return baseLocation;
    }

    private static LocationMetadata validateAirport(
            Map<String, Object> attributes,
            String cityField,
            String codeField) {
        String city = text(attributes.get(cityField)).trim();
        String code = text(attributes.get(codeField)).trim().toUpperCase(Locale.ROOT);
        LocationMetadata location = findLocation(city);
        if (location == null || !location.code().equals(code)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    cityField + " and " + codeField + " must match a supported airport");
        }
        attributes.put(cityField, location.city());
        attributes.put(codeField, code);
        return location;
    }

    private static LocationMetadata validateKnownLocation(String city, String country) {
        LocationMetadata location = findLocation(city);
        if (location == null) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Location must be selected from the supported registry");
        }
        if (country != null && !location.country().equalsIgnoreCase(country.trim())) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Country must match the selected location");
        }
        return location;
    }

    private static LocationMetadata findLocation(String city) {
        for (Map.Entry<String, LocationMetadata> entry : LOCATIONS.entrySet()) {
            if (entry.getKey().equalsIgnoreCase(city.trim())) {
                return new LocationMetadata(
                        entry.getValue().code(),
                        entry.getValue().country(),
                        entry.getValue().region(),
                        entry.getKey());
            }
        }
        return null;
    }

    private static Map<String, Object> requestAttributes(Object value) {
        if (value == null) return new LinkedHashMap<>();
        if (!(value instanceof Map<?, ?>)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "attributes must be a JSON object");
        }
        return attributes(value);
    }

    static void applyGeneratedAttributes(
            Map<String, Object> attributes,
            String type,
            long listingId,
            PartnerIdentity partner,
            boolean active) {
        String providerCode = switch (partner.slug().toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9]", "")) {
            case "libyanairlines" -> "LN";
            case "afriqiyahairlines", "afriqiyahairways" -> "8U";
            case "buraqair", "buraqairways" -> "UZ";
            case "libyanwings" -> "YL";
            default -> {
                String normalized = partner.slug()
                        .replaceAll("[^A-Za-z0-9]", "")
                        .toUpperCase(Locale.ROOT);
                yield normalized.length() < 2
                        ? normalized
                        : normalized.substring(0, 2);
            }
        };
        if (providerCode.isBlank()) providerCode = "P" + partner.id();
        String prefix = switch (type) {
            case "flight" -> "FL-" + providerCode;
            case "hotel" -> "HTL";
            case "car" -> "CAR";
            case "attraction" -> "ACT";
            case "transfer" -> "TRF";
            case "package" -> "PKG";
            default -> throw new IllegalStateException("Unsupported listing type.");
        };
        String sequence = String.format(Locale.ROOT, "%06d", listingId);
        attributes.put("listing_code", prefix + "-" + sequence);
        if ("flight".equals(type)) {
            attributes.put("airline_code", providerCode);
            attributes.put("flight_number", providerCode + "-" + listingId);
        }
        attributes.put("status", active ? "published" : "paused");
        attributes.put("is_active", active);
    }

    @GetMapping("/inventory/{type}")
    public Map<String, Object> publicInventory(
            @PathVariable String type,
            @RequestParam(required = false) String city) {
        String normalizedType = normalizeListingType(type);
        List<Map<String, Object>> rows = city == null || city.isBlank()
                ? jdbc.queryForList("""
                    SELECT l.*, p.name AS partner_name, p.slug AS partner_slug
                    FROM partner_listings l
                    JOIN partners p ON p.id = l.partner_id AND p.status = 'active'
                    WHERE l.type = ? AND l.active = TRUE
                    ORDER BY l.updated_at DESC
                    """, normalizedType)
                : jdbc.queryForList("""
                    SELECT l.*, p.name AS partner_name, p.slug AS partner_slug
                    FROM partner_listings l
                    JOIN partners p ON p.id = l.partner_id AND p.status = 'active'
                    WHERE l.type = ? AND l.active = TRUE
                      AND (LOWER(l.city) = LOWER(?) OR l.city = '')
                    ORDER BY l.updated_at DESC
                    """, normalizedType, city.trim());
        return Map.of("items", rows.stream()
                .map(row -> publicListing(row, normalizedType))
                .toList());
    }

    @GetMapping("/partner/dashboard")
    public Map<String, Object> dashboard(HttpServletRequest request) {
        PartnerIdentity partner = requirePartner(request);
        Map<String, Object> summary = jdbc.queryForMap("""
                SELECT
                    (SELECT COUNT(*) FROM partner_listings
                        WHERE partner_id = ?) AS listing_count,
                    (SELECT COUNT(*) FROM partner_listings
                        WHERE partner_id = ? AND active = TRUE) AS active_listing_count,
                    (SELECT COUNT(*) FROM trips
                        WHERE partner_id = ? AND LOWER(status) <> 'cancelled')
                      + (SELECT COUNT(*) FROM bookings
                        WHERE partner_id = ? AND LOWER(status) <> 'cancelled')
                      + (SELECT COUNT(*) FROM transfers
                        WHERE partner_id = ? AND LOWER(status) <> 'cancelled')
                        AS reservation_count,
                    (SELECT COUNT(*) FROM users u
                        WHERE u.role = 'customer' AND EXISTS (
                            SELECT 1 FROM trips t
                            WHERE t.partner_id = ? AND t.user_id = u.id
                            UNION ALL
                            SELECT 1 FROM bookings b
                            WHERE b.partner_id = ? AND b.user_id = u.id
                            UNION ALL
                            SELECT 1 FROM transfers x
                            WHERE x.partner_id = ? AND x.user_id = u.id
                        )) AS customer_count,
                    COALESCE((SELECT SUM(total_amount) FROM bookings
                        WHERE partner_id = ? AND LOWER(status) <> 'cancelled'), 0)
                      + COALESCE((SELECT SUM(price) FROM trips
                        WHERE partner_id = ? AND LOWER(status) <> 'cancelled'), 0)
                      + COALESCE((SELECT SUM(price) FROM transfers
                        WHERE partner_id = ? AND LOWER(status) <> 'cancelled'), 0)
                        AS booked_value
                """, partner.id(), partner.id(), partner.id(), partner.id(), partner.id(),
                partner.id(), partner.id(), partner.id(), partner.id(), partner.id(),
                partner.id());
        return Map.of(
                "company", Map.of(
                        "id", partner.id(),
                        "name", partner.name(),
                        "service_type", partner.serviceType()),
                "summary", summary,
                "recent_reservations", reservations(partner.id(), 8));
    }

    @GetMapping("/partner/listings")
    public Map<String, Object> listings(HttpServletRequest request) {
        PartnerIdentity partner = requirePartner(request);
        List<Map<String, Object>> listings = jdbc.queryForList("""
                SELECT id, type, title, city, country, description, image_url,
                       price, active, attributes, created_at, updated_at
                FROM partner_listings
                WHERE partner_id = ?
                ORDER BY updated_at DESC
                """, partner.id());
        for (Map<String, Object> listing : listings) {
            Map<String, Object> listingAttributes =
                    attributes(listing.get("attributes"));
            applyGeneratedAttributes(
                    listingAttributes,
                    text(listing.get("type")),
                    ((Number) listing.get("id")).longValue(),
                    partner,
                    bool(listing.get("active"), false));
            listing.put("attributes", listingAttributes);
        }
        return Map.of("listings", listings);
    }

    @PostMapping("/partner/listings")
    @Transactional
    public Map<String, Object> createListing(
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        PartnerIdentity partner = requirePartner(request);
        String type = normalizeListingType(text(body.get("type")));
        ensurePartnerCanManageType(partner, type);
        String title = required(body, "title");
        String imageUrl = listingImage(type, body.get("image_url"));
        Map<String, Object> listingAttributes =
                requestAttributes(body.get("attributes"));
        boolean active = bool(body.get("active"), true);
        LocationMetadata location = validateListingData(
                type,
                text(body.get("city")),
                listingAttributes);
        long id = insert("""
                INSERT INTO partner_listings
                    (partner_id, type, title, city, country, description, image_url,
                     price, active, attributes, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CAST(? AS JSON), NOW(), NOW())
                """, partner.id(), type, title,
                location.city(), location.country(),
                nullableText(body.get("description")), imageUrl,
                decimal(body.get("price")), active, "{}");
        applyGeneratedAttributes(listingAttributes, type, id, partner, active);
        jdbc.update("""
                UPDATE partner_listings SET attributes = CAST(? AS JSON)
                WHERE id = ? AND partner_id = ?
                """, serializeAttributes(listingAttributes), id, partner.id());
        return Map.of("listing", findListing(partner.id(), id));
    }

    @PutMapping("/partner/listings/{id}")
    @Transactional
    public Map<String, Object> updateListing(
            @PathVariable long id,
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        PartnerIdentity partner = requirePartner(request);
        Map<String, Object> existing = findListing(partner.id(), id);
        String type = value(body, "type", text(existing.get("type")));
        type = normalizeListingType(type);
        ensurePartnerCanManageType(partner, type);
        String imageUrl = body.containsKey("image_url")
                ? safeImageUrl(body.get("image_url"))
                : text(existing.get("image_url"));
        imageUrl = listingImage(type, imageUrl);
        Map<String, Object> listingAttributes = body.containsKey("attributes")
                ? requestAttributes(body.get("attributes"))
                : attributes(existing.get("attributes"));
        boolean active = body.containsKey("active")
                ? bool(body.get("active"), false)
                : bool(existing.get("active"), false);
        LocationMetadata location = validateListingData(
                type,
                value(body, "city", text(existing.get("city"))),
                listingAttributes);
        applyGeneratedAttributes(listingAttributes, type, id, partner, active);
        int updated = jdbc.update("""
                UPDATE partner_listings
                SET type = ?, title = ?, city = ?, country = ?, description = ?,
                    image_url = ?, price = ?, active = ?, attributes = CAST(? AS JSON),
                    updated_at = NOW()
                WHERE id = ? AND partner_id = ?
                """,
                normalizeListingType(type),
                value(body, "title", text(existing.get("title"))),
                location.city(),
                location.country(),
                body.containsKey("description")
                        ? nullableText(body.get("description"))
                        : existing.get("description"),
                imageUrl,
                body.containsKey("price") ? decimal(body.get("price"))
                        : decimal(existing.get("price")),
                active, serializeAttributes(listingAttributes), id, partner.id());
        if (updated != 1) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Listing not found");
        }
        return Map.of("listing", findListing(partner.id(), id));
    }

    @DeleteMapping("/partner/listings/{id}")
    @Transactional
    public Map<String, Object> deactivateListing(
            @PathVariable long id,
            HttpServletRequest request) {
        PartnerIdentity partner = requirePartner(request);
        int updated = jdbc.update("""
                UPDATE partner_listings SET active = FALSE, updated_at = NOW()
                WHERE id = ? AND partner_id = ?
                """, id, partner.id());
        if (updated != 1) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Listing not found");
        }
        return Map.of("status", "inactive");
    }

    @GetMapping("/partner/reservations")
    public Map<String, Object> partnerReservations(
            @RequestParam(defaultValue = "50") int limit,
            HttpServletRequest request) {
        PartnerIdentity partner = requirePartner(request);
        validateLimit(limit);
        return Map.of("reservations", reservations(partner.id(), limit));
    }

    @GetMapping("/partner/customers")
    public Map<String, Object> customers(
            @RequestParam(defaultValue = "50") int limit,
            HttpServletRequest request) {
        PartnerIdentity partner = requirePartner(request);
        validateLimit(limit);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT u.id, u.name, u.email, u.phone, u.created_at,
                    COUNT(reservations.id) AS reservation_count
                FROM (
                    SELECT user_id, id FROM trips WHERE partner_id = ?
                    UNION ALL
                    SELECT user_id, id FROM bookings WHERE partner_id = ?
                    UNION ALL
                    SELECT user_id, id FROM transfers WHERE partner_id = ?
                ) reservations
                JOIN users u ON u.id = reservations.user_id
                WHERE u.role = 'customer'
                GROUP BY u.id, u.name, u.email, u.phone, u.created_at
                ORDER BY MAX(reservations.id) DESC
                LIMIT ?
                """, partner.id(), partner.id(), partner.id(), limit);
        return Map.of("customers", rows);
    }

    private List<Map<String, Object>> reservations(long partnerId, int limit) {
        return jdbc.queryForList("""
                SELECT *
                FROM (
                    SELECT CONCAT('flight-', t.id) AS id, t.id AS reservation_id,
                        t.partner_listing_id, 'flight' AS type, t.title,
                        u.id AS customer_id, u.name AS customer_name,
                        u.email AS customer_email, u.phone AS customer_phone,
                        COALESCE(t.departure_date, t.created_at) AS reservation_date,
                        COALESCE(t.price, 0) AS amount, t.status, t.created_at
                    FROM trips t JOIN users u ON u.id = t.user_id
                    WHERE t.partner_id = ?
                    UNION ALL
                    SELECT CONCAT('booking-', b.id) AS id, b.id AS reservation_id,
                        b.partner_listing_id, b.type,
                        COALESCE(b.title, b.subtitle, 'Booking') AS title,
                        u.id AS customer_id, u.name AS customer_name,
                        u.email AS customer_email, u.phone AS customer_phone,
                        COALESCE(b.date, b.created_at) AS reservation_date,
                        COALESCE(b.total_amount, b.price, 0) AS amount,
                        b.status, b.created_at
                    FROM bookings b JOIN users u ON u.id = b.user_id
                    WHERE b.partner_id = ?
                    UNION ALL
                    SELECT CONCAT('transfer-', x.id) AS id, x.id AS reservation_id,
                        x.partner_listing_id, 'transfer' AS type,
                        CONCAT(x.pickup_location, ' to ', x.dropoff_location) AS title,
                        u.id AS customer_id, u.name AS customer_name,
                        u.email AS customer_email, u.phone AS customer_phone,
                        x.pickup_time AS reservation_date, x.price AS amount,
                        x.status, x.created_at
                    FROM transfers x JOIN users u ON u.id = x.user_id
                    WHERE x.partner_id = ?
                ) reservations
                ORDER BY created_at DESC
                LIMIT ?
                """, partnerId, partnerId, partnerId, limit);
    }

    private Map<String, Object> publicListing(
            Map<String, Object> row,
            String type) {
        Map<String, Object> listing = new LinkedHashMap<>(attributes(row.get("attributes")));
        long id = ((Number) row.get("id")).longValue();
        String title = text(row.get("title"));
        String city = text(row.get("city"));
        String country = text(row.get("country"));
        String partnerName = text(row.get("partner_name"));
        Object partnerSlug = row.get("partner_slug");
        if (partnerSlug != null) {
            applyGeneratedAttributes(
                    listing,
                    type,
                    id,
                    new PartnerIdentity(0, partnerName, "", text(partnerSlug)),
                    true);
        }
        listing.put("id", "partner-" + id);
        listing.put("partner_listing_id", id);
        listing.put("partner_name", partnerName);
        listing.put("city", city);
        listing.put("country", country);
        listing.put("description", text(row.get("description")));
        listing.put("image_url", "flight".equals(type) ? null : row.get("image_url"));
        switch (type) {
            case "flight" -> {
                listing.put("airline", partnerName);
                listing.put("title", title);
                listing.put("origin_city", value(listing, "origin_city", city));
                listing.put("origin_code", value(listing, "origin_code", ""));
                listing.put("destination_city",
                        value(listing, "destination_city", ""));
                listing.put("destination_code",
                        value(listing, "destination_code", ""));
                listing.putIfAbsent("flight_number", "");
                listing.putIfAbsent("airline_code", "");
                listing.put("status", "published");
                listing.put("is_active", true);
                listing.put("economy_price", row.get("price"));
                listing.put("airline_logo_url", null);
            }
            case "hotel" -> {
                listing.put("name", title);
                listing.put("address", value(listing, "address", city));
                listing.put("price_per_night", row.get("price"));
                listing.putIfAbsent("rating", 0);
                listing.putIfAbsent("review_count", 0);
                listing.putIfAbsent("stars", 0);
                listing.putIfAbsent("amenities", List.of());
                listing.put("status", "published");
                listing.put("is_active", true);
            }
            case "car" -> {
                listing.putIfAbsent("brand", partnerName);
                listing.putIfAbsent("model", title);
                listing.putIfAbsent("category", "economy");
                listing.putIfAbsent("year", 2026);
                listing.put("price_per_day", row.get("price"));
                listing.putIfAbsent("seats", 4);
                listing.putIfAbsent("transmission", "automatic");
                listing.putIfAbsent("fuel_type", "gasoline");
                listing.putIfAbsent("features", List.of());
                listing.putIfAbsent("rating", 0);
                listing.put("pickup_location", value(listing, "pickup_location", city));
                listing.putIfAbsent("has_ac", true);
                listing.putIfAbsent("has_gps", false);
                listing.put("status", "published");
                listing.put("is_active", true);
            }
            case "attraction" -> {
                listing.put("name", title);
                listing.put("entry_fee", row.get("price"));
                listing.putIfAbsent("category", "landmark");
                listing.putIfAbsent("rating", 0);
                listing.putIfAbsent("review_count", 0);
                listing.putIfAbsent("latitude", 0);
                listing.putIfAbsent("longitude", 0);
                listing.putIfAbsent("tags", List.of());
                listing.putIfAbsent("opening_hours", "");
                listing.put("status", "published");
                listing.put("is_active", true);
            }
            case "transfer" -> {
                listing.put("provider_name", partnerName);
                listing.put("vehicle_name", title);
                listing.put("vehicle_type", value(listing, "vehicle_type", "sedan"));
                listing.put("price", row.get("price"));
                listing.putIfAbsent("max_passengers", 4);
                listing.putIfAbsent("max_luggage", 2);
                listing.putIfAbsent("pickup_location", city);
                listing.putIfAbsent("dropoff_location", "");
                listing.putIfAbsent("duration_minutes", 60);
                listing.putIfAbsent("included_services", List.of());
                listing.put("status", "published");
                listing.put("is_active", true);
                listing.put("vehicle_image_url", row.get("image_url"));
            }
            case "package" -> {
                listing.put("title", title);
                listing.put("location", city);
                listing.put("country", country);
                listing.put("flight_price_per_person", row.get("price"));
                listing.put("hotel_price_per_night", 0);
                listing.putIfAbsent("duration_nights", 1);
                listing.putIfAbsent("highlights", List.of());
                listing.put("status", "published");
                listing.put("is_active", true);
            }
            default -> throw new IllegalStateException("Unsupported listing type.");
        }
        return listing;
    }

    private Map<String, Object> findListing(long partnerId, long id) {
        try {
            return jdbc.queryForMap("""
                    SELECT id, partner_id, type, title, city, country, description,
                           image_url, price, active, attributes, created_at, updated_at
                    FROM partner_listings
                    WHERE id = ? AND partner_id = ?
                    """, id, partnerId);
        } catch (org.springframework.dao.EmptyResultDataAccessException exception) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Listing not found");
        }
    }

    private PartnerIdentity requirePartner(HttpServletRequest request) {
        Object userId = request.getAttribute("authUserId");
        if (!(userId instanceof Number number)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthenticated");
        }
        try {
            Map<String, Object> user = jdbc.queryForMap("""
                    SELECT u.partner_id, p.name, p.service_type, p.slug
                    FROM users u JOIN partners p ON p.id = u.partner_id
                    WHERE u.id = ? AND u.role = 'partner' AND p.status = 'active'
                    """, number.longValue());
            return new PartnerIdentity(
                    ((Number) user.get("partner_id")).longValue(),
                    text(user.get("name")),
                    text(user.get("service_type")),
                    text(user.get("slug")));
        } catch (org.springframework.dao.EmptyResultDataAccessException exception) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Active partner access required");
        }
    }

    private static void ensurePartnerCanManageType(
            PartnerIdentity partner, String listingType) {
        String requiredService = switch (listingType) {
            case "flight" -> "airline";
            case "hotel" -> "hotel";
            case "car" -> "car";
            case "attraction" -> "attraction";
            case "transfer" -> "transfer";
            case "package" -> "travel";
            default -> throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Unsupported listing type");
        };
        if (!requiredService.equals(partner.serviceType())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "This company cannot manage that listing type");
        }
    }

    private static String normalizeListingType(String type) {
        String normalized = type.trim().toLowerCase(Locale.ROOT);
        if (!LISTING_TYPES.contains(normalized)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Unsupported listing type");
        }
        return normalized;
    }

    private static void validateLimit(int limit) {
        if (limit < 1 || limit > 100) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "limit must be between 1 and 100");
        }
    }

    private static String required(Map<String, Object> body, String key) {
        String value = text(body.get(key)).trim();
        if (value.isEmpty()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, key + " is required");
        }
        return value;
    }

    private static String text(Object value) {
        return value == null ? "" : value.toString();
    }

    private static String value(
            Map<String, Object> body, String key, String fallback) {
        return body.get(key) == null ? fallback : text(body.get(key));
    }

    private static String nullableText(Object value) {
        String text = text(value).trim();
        return text.isEmpty() ? null : text;
    }

    private static String safeImageUrl(Object value) {
        String url = text(value).trim();
        if (url.isEmpty()) return null;
        if (url.length() > 2048
                || !(url.startsWith("https://") || url.startsWith("http://"))) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "image_url must be a valid HTTP(S) URL");
        }
        return url;
    }

    private static String listingImage(String type, Object imageValue) {
        String imageUrl = safeImageUrl(imageValue);
        if ("hotel".equals(type) && (imageUrl == null || imageUrl.isBlank())) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Hotel listings require a photo URL");
        }
        return imageUrl;
    }

    private static BigDecimal decimal(Object value) {
        try {
            BigDecimal amount = new BigDecimal(text(value).isBlank() ? "0" : text(value));
            if (amount.signum() < 0 || amount.precision() > 10 || amount.scale() > 2) {
                throw new NumberFormatException();
            }
            return amount;
        } catch (NumberFormatException exception) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "price must be a non-negative amount with at most two decimals");
        }
    }

    private static boolean bool(Object value, boolean fallback) {
        if (value instanceof Boolean result) return result;
        if (value instanceof Number number) return number.intValue() != 0;
        if (value instanceof String text) {
            if ("true".equalsIgnoreCase(text) || "1".equals(text)) return true;
            if ("false".equalsIgnoreCase(text) || "0".equals(text)) return false;
        }
        return fallback;
    }

    private static String serializeAttributes(Object raw) {
        try {
            return JSON.writeValueAsString(attributes(raw));
        } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
            throw new IllegalStateException("Could not serialize listing attributes", exception);
        }
    }

    private static Map<String, Object> attributes(Object raw) {
        if (raw instanceof Map<?, ?> map) {
            Map<String, Object> result = new LinkedHashMap<>();
            map.forEach((key, value) -> result.put(key.toString(), value));
            return result;
        }
        if (raw == null) return new LinkedHashMap<>();
        try {
            return JSON.readValue(raw.toString(), new TypeReference<>() {});
        } catch (com.fasterxml.jackson.core.JsonProcessingException exception) {
            throw new IllegalStateException("Could not parse stored listing attributes", exception);
        }
    }

    private long insert(String sql, Object... args) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement statement =
                    connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            for (int i = 0; i < args.length; i++) {
                statement.setObject(i + 1, args[i]);
            }
            return statement;
        }, keyHolder);
        Number key = keyHolder.getKey();
        if (key == null) throw new IllegalStateException("Listing insert did not return an ID");
        return key.longValue();
    }

    record PartnerIdentity(long id, String name, String serviceType, String slug) {}

    private record LocationMetadata(
            String code, String country, String region, String city) {
        private LocationMetadata(String code, String country, String region) {
            this(code, country, region, "");
        }
    }
}
