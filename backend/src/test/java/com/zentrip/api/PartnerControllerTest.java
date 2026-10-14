package com.zentrip.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.LinkedHashMap;

import org.junit.jupiter.api.Test;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PartnerControllerTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final PartnerController controller = new PartnerController(jdbc);

    @Test
    void hotelListingsRequireAHostedPhoto() {
        when(jdbc.queryForMap(contains("FROM users u JOIN partners p"), eq(7L)))
                .thenReturn(Map.of(
                        "partner_id", 3L,
                        "name", "Example Hotel",
                        "service_type", "hotel"));

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> controller.createListing(
                        Map.of("type", "hotel", "title", "No Photo", "price", 80),
                        authenticatedRequest()));

        assertEquals(400, error.getStatusCode().value());
        verify(jdbc, never()).update(org.mockito.ArgumentMatchers.any(
                org.springframework.jdbc.core.PreparedStatementCreator.class),
                org.mockito.ArgumentMatchers.any(
                        org.springframework.jdbc.support.KeyHolder.class));
    }

    @Test
    void partnerCannotReadOrUpdateAnotherCompanyListing() {
        when(jdbc.queryForMap(contains("FROM users u JOIN partners p"), eq(7L)))
                .thenReturn(Map.of(
                        "partner_id", 3L,
                        "name", "Example Hotel",
                        "service_type", "hotel"));
        when(jdbc.queryForMap(
                contains("WHERE id = ? AND partner_id = ?"),
                eq(42L),
                eq(3L)))
                .thenThrow(new EmptyResultDataAccessException(1));

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> controller.updateListing(
                        42L, Map.of("title", "Other company's hotel"), authenticatedRequest()));

        assertEquals(404, error.getStatusCode().value());
        verify(jdbc, never()).update(contains("UPDATE partner_listings SET"));
    }

    @Test
    void publicHotelInventoryIncludesPartnerMetadataAndListingPrice() {
        when(jdbc.queryForList(contains("FROM partner_listings l"), eq("hotel")))
                .thenReturn(List.of(Map.ofEntries(
                        Map.entry("id", 42L),
                        Map.entry("type", "hotel"),
                        Map.entry("title", "Partner Hotel"),
                        Map.entry("city", "Tripoli"),
                        Map.entry("country", "Libya"),
                        Map.entry("partner_name", "Example Hotel"),
                        Map.entry("description", "Sea view"),
                        Map.entry("image_url", "https://example.com/hotel.jpg"),
                        Map.entry("price", new BigDecimal("84.50")),
                        Map.entry("attributes", "{\"stars\":4,\"amenities\":[\"wifi\"]}"))));

        Map<String, Object> response = controller.publicInventory("hotel", null);
        Map<?, ?> listing = (Map<?, ?>) ((List<?>) response.get("items")).getFirst();

        assertEquals("partner-42", listing.get("id"));
        assertEquals(42L, listing.get("partner_listing_id"));
        assertEquals("Example Hotel", listing.get("partner_name"));
        assertEquals(new BigDecimal("84.50"), listing.get("price_per_night"));
        assertEquals("https://example.com/hotel.jpg", listing.get("image_url"));
        assertEquals(4, listing.get("stars"));
    }

    @Test
    void publicActiveFlightInventoryExposesSearchableRouteWithoutImages() {
        when(jdbc.queryForList(contains("FROM partner_listings l"), eq("flight")))
                .thenReturn(List.of(Map.ofEntries(
                        Map.entry("id", 25L),
                        Map.entry("type", "flight"),
                        Map.entry("title", "Misrata to Tripoli"),
                        Map.entry("city", "Misrata"),
                        Map.entry("country", "Libya"),
                        Map.entry("partner_name", "Libyan Wings"),
                        Map.entry("partner_slug", "libyan-wings"),
                        Map.entry("description", "Partner flight"),
                        Map.entry("image_url", "https://example.com/should-not-be-used.png"),
                        Map.entry("active", true),
                        Map.entry("price", new BigDecimal("175.00")),
                        Map.entry("attributes", """
                                {"origin_city":"Misrata","origin_code":"MRA",
                                 "destination_city":"Tripoli","destination_code":"MJI",
                                 "flight_number":"MANUAL-204","departure_time":"2026-11-10T08:00:00",
                                 "arrival_time":"2026-11-10T10:00:00","duration_minutes":120,
                                 "seats_available":80}
                                """))));

        Map<String, Object> response = controller.publicInventory("flight", null);
        Map<?, ?> listing = (Map<?, ?>) ((List<?>) response.get("items")).getFirst();

        assertEquals("Misrata", listing.get("origin_city"));
        assertEquals("MRA", listing.get("origin_code"));
        assertEquals("Tripoli", listing.get("destination_city"));
        assertEquals("MJI", listing.get("destination_code"));
        assertEquals("YL-25", listing.get("flight_number"));
        assertEquals("YL", listing.get("airline_code"));
        assertEquals("FL-YL-000025", listing.get("listing_code"));
        assertEquals("2026-11-10T08:00:00", listing.get("departure_time"));
        assertEquals("published", listing.get("status"));
        assertEquals(true, listing.get("is_active"));
        assertEquals(null, listing.get("image_url"));
        assertEquals(null, listing.get("airline_logo_url"));
        verify(jdbc).queryForList(
                contains("WHERE l.type = ? AND l.active = TRUE"),
                eq("flight"));
    }

    @Test
    void publicInventoryMapsCustomerContractsForCarsAttractionsTransfersAndPackages() {
        assertPublicListing("car", Map.of(
                "category", "suv",
                "seats", 5,
                "transmission", "automatic",
                "fuel_type", "hybrid",
                "features", List.of("GPS"),
                "has_ac", true,
                "has_gps", true),
                Map.of(
                        "category", "suv",
                        "price_per_day", new BigDecimal("48.00"),
                        "has_gps", true));
        assertPublicListing("attraction", Map.of(
                "category", "museum",
                "opening_hours", "09:00-17:00",
                "latitude", 32.9,
                "longitude", 13.2,
                "tags", List.of("history")),
                Map.of(
                        "category", "museum",
                        "entry_fee", new BigDecimal("48.00"),
                        "opening_hours", "09:00-17:00"));
        assertPublicListing("transfer", Map.of(
                "vehicle_type", "minivan",
                "max_passengers", 6,
                "max_luggage", 4,
                "pickup_location", "Tripoli",
                "dropoff_location", "Misrata",
                "pickup_time", "2026-11-10T09:00:00",
                "duration_minutes", 180,
                "included_services", List.of("Wi-Fi")),
                Map.of(
                        "vehicle_type", "minivan",
                        "max_passengers", 6,
                        "pickup_location", "Tripoli",
                        "dropoff_location", "Misrata",
                        "pickup_time", "2026-11-10T09:00:00",
                        "duration_minutes", 180));
        assertPublicListing("package", Map.of(
                "duration_nights", 3,
                "category", "city",
                "highlights", List.of("Old town")),
                Map.of(
                        "location", "Tripoli",
                        "flight_price_per_person", new BigDecimal("48.00"),
                        "duration_nights", 3));
    }

    @Test
    void createRejectsFlightLocationsOutsideTheSharedRegistry() {
        when(jdbc.queryForMap(contains("FROM users u JOIN partners p"), eq(7L)))
                .thenReturn(Map.of(
                        "partner_id", 3L,
                        "name", "Libyan Wings",
                        "service_type", "airline",
                        "slug", "libyan-wings"));

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> controller.createListing(
                        Map.of(
                                "type", "flight",
                                "title", "Unknown airport route",
                                "city", "Tripoli",
                                "country", "Libya",
                                "price", 100,
                                "attributes", Map.of(
                                        "origin_city", "Tripoli",
                                        "origin_code", "MIP",
                                        "destination_city", "Cairo",
                                        "destination_code", "CAI")),
                        authenticatedRequest()));

        assertEquals(400, error.getStatusCode().value());
    }

    @Test
    void partnerCanCreateOnlyListingsForItsConfiguredSpecialty() {
        when(jdbc.queryForMap(contains("FROM users u JOIN partners p"), eq(7L)))
                .thenReturn(Map.of(
                        "partner_id", 3L,
                        "name", "Libyan Wings",
                        "service_type", "airline",
                        "slug", "libyan-wings"));

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> controller.createListing(
                        Map.of(
                                "type", "hotel",
                                "title", "Not an airline product",
                                "city", "Tripoli",
                                "country", "Libya",
                                "price", 100),
                        authenticatedRequest()));

        assertEquals(403, error.getStatusCode().value());
        verify(jdbc, never()).update(org.mockito.ArgumentMatchers.any(
                org.springframework.jdbc.core.PreparedStatementCreator.class),
                org.mockito.ArgumentMatchers.any(
                        org.springframework.jdbc.support.KeyHolder.class));
    }

    private void assertPublicListing(
            String type,
            Map<String, Object> attributes,
            Map<String, Object> expected) {
        when(jdbc.queryForList(contains("FROM partner_listings l"), eq(type)))
                .thenReturn(List.of(Map.ofEntries(
                        Map.entry("id", 42L),
                        Map.entry("type", type),
                        Map.entry("title", "Partner " + type),
                        Map.entry("city", "Tripoli"),
                        Map.entry("country", "Libya"),
                        Map.entry("partner_name", "Example Provider"),
                        Map.entry("description", "Partner inventory"),
                        Map.entry("image_url", "https://example.com/item.jpg"),
                        Map.entry("price", new BigDecimal("48.00")),
                        Map.entry("attributes", attributes))));

        Map<String, Object> response = controller.publicInventory(type, null);
        Map<?, ?> listing = (Map<?, ?>) ((List<?>) response.get("items")).getFirst();
        for (Map.Entry<String, Object> field : expected.entrySet()) {
            assertEquals(field.getValue(), listing.get(field.getKey()),
                    type + " field " + field.getKey());
        }
        assertEquals(42L, listing.get("partner_listing_id"));
        assertEquals(true, listing.get("is_active"));
    }

    @Test
    void generatedListingAndFlightCodesOverrideClientValues() {
        Map<String, Object> attributes = new LinkedHashMap<>(Map.of(
                "listing_code", "PARTNER-CHOSEN",
                "flight_number", "MANUAL-123",
                "status", "paused",
                "is_active", false));

        PartnerController.applyGeneratedAttributes(
                attributes,
                "flight",
                405L,
                new PartnerController.PartnerIdentity(
                        5L, "Libyan Wings", "airline", "libyan-wings"),
                true);

        assertEquals("FL-YL-000405", attributes.get("listing_code"));
        assertEquals("YL-405", attributes.get("flight_number"));
        assertEquals("YL", attributes.get("airline_code"));
        assertEquals("published", attributes.get("status"));
        assertEquals(true, attributes.get("is_active"));
    }

    @Test
    void generatedReferencesCoverEverySupportedInventoryType() {
        var partner = new PartnerController.PartnerIdentity(
                5L, "Travel Partner", "travel", "travel-partner");
        Map<String, String> expectedPrefixes = Map.of(
                "flight", "FL-TR-000012",
                "hotel", "HTL-000012",
                "car", "CAR-000012",
                "attraction", "ACT-000012",
                "transfer", "TRF-000012",
                "package", "PKG-000012");

        expectedPrefixes.forEach((type, expected) -> {
            Map<String, Object> attributes = new LinkedHashMap<>();
            PartnerController.applyGeneratedAttributes(
                    attributes, type, 12L, partner, true);
            assertEquals(expected, attributes.get("listing_code"));
        });
    }

    @Test
    void aUserWithoutPartnerRoleIsForbiddenFromPartnerData() {
        when(jdbc.queryForMap(contains("FROM users u JOIN partners p"), eq(7L)))
                .thenThrow(new EmptyResultDataAccessException(1));

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> controller.listings(authenticatedRequest()));

        assertEquals(403, error.getStatusCode().value());
    }

    private static MockHttpServletRequest authenticatedRequest() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute("authUserId", 7L);
        return request;
    }
}
