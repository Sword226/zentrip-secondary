package com.zentrip.api;

import java.sql.Timestamp;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

class ApiControllerTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
        private final ProfilePhotoStorage photoStorage = mock(ProfilePhotoStorage.class);
        private final ApiController controller = new ApiController(jdbc, "", photoStorage);

    @Test
    void invalidLoginReturnsLaravelValidationResponse() {
        when(jdbc.queryForList("SELECT id, password FROM users WHERE email = ?", "user@example.com"))
                .thenReturn(List.of());

        ResponseEntity<?> response = controller.login(Map.of(
                "email", "user@example.com",
                "password", "incorrect-password"), new MockHttpServletRequest());

        assertEquals(422, response.getStatusCode().value());
        assertEquals(Map.of(
                "message", "The given data was invalid.",
                "errors", Map.of("email", List.of("The provided credentials are incorrect."))),
                response.getBody());
    }

        @Test
        void offersReturnsFieldsAndHighlightsExpectedByFlutter() {
                when(jdbc.queryForList(contains("FROM offers"))).thenReturn(List.of(
                                new java.util.LinkedHashMap<>(Map.ofEntries(
                                                Map.entry("id", "istanbul-dream"),
                                                Map.entry("title", "Istanbul Dream"),
                                                Map.entry("location", "Istanbul"),
                                                Map.entry("country", "Turkey"),
                                                Map.entry("destination_code", "IST"),
                                                Map.entry("description", "Historic city break"),
                                                Map.entry("image_url", "https://example.com/istanbul.jpg"),
                                                Map.entry("price_per_person", new java.math.BigDecimal("1290.00")),
                                                Map.entry("flight_price_per_person", new java.math.BigDecimal("420.00")),
                                                Map.entry("hotel_price_per_night", new java.math.BigDecimal("95.00")),
                                                Map.entry("duration_nights", 7),
                                                Map.entry("rating", new java.math.BigDecimal("4.80")),
                                                Map.entry("review_count", 2340),
                                                Map.entry("highlights", "[\"Blue Mosque\",\"Hagia Sophia\"]"),
                                                Map.entry("is_featured", true),
                                                Map.entry("category", "cultural")))));

                Map<String, Object> response = controller.offers();
                List<?> offers = (List<?>) response.get("offers");
                Map<?, ?> offer = (Map<?, ?>) offers.getFirst();

                assertEquals(1, offers.size());
                assertEquals("istanbul-dream", offer.get("id"));
                assertEquals("IST", offer.get("destination_code"));
                assertEquals(List.of("Blue Mosque", "Hagia Sophia"), offer.get("highlights"));
                assertEquals(true, offer.get("is_featured"));
        }

    @Test
    void duplicateRegistrationEmailReturnsLaravelValidationResponse() {
        when(jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE email = ?", Integer.class, "user@example.com"))
                .thenReturn(1);

        ResponseEntity<?> response = controller.register(
                "Test User", "user@example.com", "123456789", "password123", "password123", null,
                new MockHttpServletRequest());

        assertEquals(422, response.getStatusCode().value());
        assertEquals(Map.of(
                "message", "The given data was invalid.",
                "errors", Map.of("email", List.of("The email has already been taken."))),
                response.getBody());
    }

    @Test
    void rejectsAFlightThatOverlapsAnExistingCustomerTrip() {
        when(jdbc.queryForList(contains("FOR UPDATE"), eq(7L)))
                .thenReturn(List.of(Map.of("id", 7L)));
        when(jdbc.queryForList(contains("FROM trips"), eq(7L)))
                .thenReturn(List.of(Map.of(
                        "departure_date", Timestamp.valueOf("2026-11-10 10:00:00"),
                        "arrival_date", "2026-11-10T17:00",
                        "status", "upcoming")));
        MockHttpServletRequest request = authenticatedRequest();

        ResponseEntity<?> response = controller.createTrip(Map.of(
                "origin_code", "JFK",
                "origin_city", "New York",
                "destination_code", "LHR",
                "destination_city", "London",
                "departure_date", "2026-11-10T10:00:00Z",
                "arrival_date", "2026-11-10T17:00:00Z",
                "flight_number", "ZT100"), request);

        assertEquals(409, response.getStatusCode().value());
        assertEquals(Map.of("message", "FLIGHT_SCHEDULE_CONFLICT"), response.getBody());
        verify(jdbc, never()).update(any(org.springframework.jdbc.core.PreparedStatementCreator.class),
                any(org.springframework.jdbc.support.KeyHolder.class));
    }

    @Test
    void aFlightBookingCannotUseAHotelPartnerListing() {
        when(jdbc.queryForList(contains("FROM partner_listings l"), eq(51L)))
                .thenReturn(List.of(Map.of(
                        "id", 51L,
                        "partner_id", 9L,
                        "type", "hotel",
                        "active", true,
                        "price", 150)));

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> controller.createTrip(Map.of(
                        "origin_code", "MJI",
                        "origin_city", "Tripoli",
                        "destination_code", "CAI",
                        "destination_city", "Cairo",
                        "departure_date", "2026-11-10T08:00:00",
                        "arrival_date", "2026-11-10T10:00:00",
                        "flight_number", "MANUAL-1",
                        "partner_listing_id", 51), authenticatedRequest()));

        assertEquals(422, error.getStatusCode().value());
        verify(jdbc, never()).update(any(
                org.springframework.jdbc.core.PreparedStatementCreator.class),
                any(org.springframework.jdbc.support.KeyHolder.class));
    }

    @Test
    void rejectsAnotherFlightOnTheSameCalendarDateEvenWhenTimesDoNotOverlap() {
        when(jdbc.queryForList(contains("FOR UPDATE"), eq(7L)))
                .thenReturn(List.of(Map.of("id", 7L)));
        when(jdbc.queryForList(contains("FROM trips"), eq(7L)))
                .thenReturn(List.of(Map.of(
                        "departure_date", Timestamp.valueOf("2026-10-17 06:00:00"),
                        "arrival_date", "2026-10-17T08:00",
                        "airline", "First Airline",
                        "status", "upcoming")));

        ResponseEntity<?> response = controller.createTrip(Map.of(
                "origin_code", "JFK",
                "origin_city", "New York",
                "destination_code", "LHR",
                "destination_city", "London",
                "departure_date", "2026-10-17T17:00:00Z",
                "arrival_date", "2026-10-17T20:00:00Z",
                "flight_number", "ZT200",
                "airline", "Different Airline"), authenticatedRequest());

        assertEquals(409, response.getStatusCode().value());
        assertEquals(Map.of("message", "FLIGHT_SCHEDULE_CONFLICT"), response.getBody());
        verify(jdbc, never()).update(any(org.springframework.jdbc.core.PreparedStatementCreator.class),
                any(org.springframework.jdbc.support.KeyHolder.class));
    }

    @Test
    void rejectsFlightDuringExistingRoundTripReturnWindow() {
        when(jdbc.queryForList(contains("FOR UPDATE"), eq(7L)))
                .thenReturn(List.of(Map.of("id", 7L)));
        when(jdbc.queryForList(contains("FROM trips"), eq(7L)))
                .thenReturn(List.of(Map.of(
                        "departure_date", Timestamp.valueOf("2026-11-10 10:00:00"),
                        "arrival_date", "2026-11-10T17:00",
                        "return_date", Timestamp.valueOf("2026-11-20 00:00:00"),
                        "status", "upcoming")));

        ResponseEntity<?> response = controller.createTrip(Map.of(
                "origin_code", "DXB",
                "origin_city", "Dubai",
                "destination_code", "CAI",
                "destination_city", "Cairo",
                "departure_date", "2026-11-15T10:00:00Z",
                "arrival_date", "2026-11-15T13:00:00Z",
                "flight_number", "ZT200"), authenticatedRequest());

        assertEquals(409, response.getStatusCode().value());
        assertEquals(Map.of("message", "FLIGHT_SCHEDULE_CONFLICT"), response.getBody());
        verify(jdbc, never()).update(any(org.springframework.jdbc.core.PreparedStatementCreator.class),
                any(org.springframework.jdbc.support.KeyHolder.class));
    }

        @Test
        void genericBookingEndpointCannotBypassFlightScheduleChecks() {
                ResponseStatusException exception = assertThrows(
                                ResponseStatusException.class,
                                () -> controller.createBooking(Map.of(
                                                "type", "flight",
                                                "title", "New York to London",
                                                "subtitle", "ZT100",
                                                "date", "2026-11-10T10:00:00Z"), authenticatedRequest()));

                assertEquals(422, exception.getStatusCode().value());
                verifyNoInteractions(jdbc);
        }

        @Test
        void flightCancellationKeepsTripAndStartsRefundReview() {
                when(jdbc.queryForList(contains("FOR UPDATE"), eq(12L), eq(7L)))
                                .thenReturn(List.of(Map.of(
                                                "id", 12L,
                                                "status", "upcoming",
                                                "refund_status", "",
                                                "refund_method", "")));
                when(jdbc.update(contains("JSON_SET"), eq(12L), eq(7L))).thenReturn(1);

                ResponseEntity<?> response = controller.deleteTrip(12L, authenticatedRequest());

                assertEquals(200, response.getStatusCode().value());
                assertEquals(Map.of(
                                "status", "cancelled",
                                "refund_status", "pending_airline_review",
                                "refund_method", "original_payment_method"), response.getBody());
                verify(jdbc, never()).update(contains("DELETE FROM trips"), eq(12L), eq(7L));
        }

        @Test
        void repeatedFlightCancellationDoesNotRestartRefundProcessing() {
                when(jdbc.queryForList(contains("FOR UPDATE"), eq(12L), eq(7L)))
                                .thenReturn(List.of(Map.of(
                                                "id", 12L,
                                                "status", "cancelled",
                                                "refund_status", "pending_airline_review",
                                                "refund_method", "original_payment_method")));

                ResponseEntity<?> response = controller.deleteTrip(12L, authenticatedRequest());

                assertEquals(200, response.getStatusCode().value());
                assertEquals("pending_airline_review", ((Map<?, ?>) response.getBody()).get("refund_status"));
                verify(jdbc, never()).update(contains("JSON_SET"), eq(12L), eq(7L));
        }

            @Test
            void rejectsHotelBookingThatOverlapsAnExistingStay() {
                when(jdbc.queryForList(contains("FOR UPDATE"), eq(7L)))
                        .thenReturn(List.of(Map.of("id", 7L)));
                when(jdbc.queryForList(contains("FROM bookings"), eq(7L), eq("hotel")))
                        .thenReturn(List.of(Map.of(
                                "title", "City Hotel",
                                "date", Timestamp.valueOf("2026-11-10 15:00:00"),
                                "end_date", "2026-11-14T11:00:00")));

                ResponseEntity<?> response = controller.createBooking(Map.of(
                        "type", "hotel",
                        "title", "Another Hotel",
                        "subtitle", "Cairo",
                        "date", "2026-11-12T15:00:00Z",
                        "end_date", "2026-11-15T11:00:00Z",
                        "price", 350), authenticatedRequest());

                assertEquals(409, response.getStatusCode().value());
                assertEquals(Map.of("message", "BOOKING_SCHEDULE_CONFLICT"), response.getBody());
                verify(jdbc, never()).update(any(org.springframework.jdbc.core.PreparedStatementCreator.class),
                        any(org.springframework.jdbc.support.KeyHolder.class));
            }

    @Test
    void rejectsCarRentalThatOverlapsAnExistingRental() {
        when(jdbc.queryForList(contains("FOR UPDATE"), eq(7L)))
                .thenReturn(List.of(Map.of("id", 7L)));
        when(jdbc.queryForList(contains("FROM bookings"), eq(7L), eq("car")))
                .thenReturn(List.of(Map.of(
                        "title", "Sedan",
                        "date", Timestamp.valueOf("2026-11-10 09:00:00"),
                        "end_date", "2026-11-12T09:00:00")));

        ResponseEntity<?> response = controller.createBooking(Map.of(
                "type", "car",
                "title", "SUV",
                "subtitle", "Airport",
                "date", "2026-11-11T12:00:00Z",
                "end_date", "2026-11-13T12:00:00Z",
                "price", 200), authenticatedRequest());

        assertEquals(409, response.getStatusCode().value());
        assertEquals(Map.of("message", "BOOKING_SCHEDULE_CONFLICT"), response.getBody());
    }

    @Test
    void cancelsOwnedBookingAndMakesItAvailableForMyTripsCancelledTab() {
        when(jdbc.queryForList(contains("FROM bookings"), eq(18L), eq(7L)))
                .thenReturn(List.of(Map.of("status", "upcoming")));
        when(jdbc.update(contains("UPDATE bookings SET status = 'cancelled'"),
                eq(18L), eq(7L))).thenReturn(1);

        ResponseEntity<?> response = controller.cancelBooking(18L, authenticatedRequest());

        assertEquals(200, response.getStatusCode().value());
        assertEquals(Map.of("status", "cancelled"), response.getBody());
        verify(jdbc).update(contains("UPDATE bookings SET status = 'cancelled'"),
                eq(18L), eq(7L));
    }

    @Test
    void cannotCancelAnotherUsersBooking() {
        when(jdbc.queryForList(contains("FROM bookings"), eq(18L), eq(7L)))
                .thenReturn(List.of());

        ResponseStatusException exception = assertThrows(
                ResponseStatusException.class,
                () -> controller.cancelBooking(18L, authenticatedRequest()));

        assertEquals(404, exception.getStatusCode().value());
        verify(jdbc, never()).update(contains("UPDATE bookings SET status = 'cancelled'"),
                eq(18L), eq(7L));
    }

    @Test
    void completedBookingCannotBeCancelled() {
        when(jdbc.queryForList(contains("FROM bookings"), eq(18L), eq(7L)))
                .thenReturn(List.of(Map.of("status", "completed")));

        ResponseStatusException exception = assertThrows(
                ResponseStatusException.class,
                () -> controller.cancelBooking(18L, authenticatedRequest()));

        assertEquals(409, exception.getStatusCode().value());
        verify(jdbc, never()).update(contains("UPDATE bookings SET status = 'cancelled'"),
                eq(18L), eq(7L));
    }

    @Test
    void rejectsOverlappingTaxiBookingsForTheSameCustomer() {
        when(jdbc.queryForList(contains("FOR UPDATE"), eq(7L)))
                .thenReturn(List.of(Map.of("id", 7L)));
        when(jdbc.queryForList(contains("FROM transfers"), eq(7L)))
                .thenReturn(List.of(Map.of(
                        "pickup_time", Timestamp.valueOf("2026-11-10 10:00:00"),
                        "duration_minutes", 45,
                        "status", "confirmed")));

        ResponseEntity<?> response = controller.createTransfer(Map.of(
                "provider_name", "Zentrip Taxi",
                "vehicle_type", "sedan",
                "pickup_location", "Airport",
                "dropoff_location", "Hotel",
                "pickup_time", "2026-11-10T10:30:00",
                "duration_minutes", 30,
                "price", 35,
                "passengers", 2), authenticatedRequest());

        assertEquals(409, response.getStatusCode().value());
        assertEquals(Map.of("message", "TAXI_SCHEDULE_CONFLICT"), response.getBody());
        verify(jdbc, never()).update(any(org.springframework.jdbc.core.PreparedStatementCreator.class),
                any(org.springframework.jdbc.support.KeyHolder.class));
    }

    @Test
    void bookingDetailsStoreOnlyHttpCoverImages() throws Exception {
        java.time.LocalDateTime end = java.time.LocalDateTime.parse("2026-11-12T09:00:00");

        String withImage = ApiController.bookingDetailsJson(end, " https://example.com/car.jpg ");
        String unsafe = ApiController.bookingDetailsJson(end, "javascript:alert(1)");
        String missing = ApiController.bookingDetailsJson(end, null);

        assertTrue(withImage.contains("\"image_url\":\"https://example.com/car.jpg\""));
        assertTrue(withImage.contains("\"end_date\":\"2026-11-12T09:00\""));
        assertTrue(!unsafe.contains("image_url"));
        assertTrue(!missing.contains("image_url"));
    }

    @Test
    void rejectsDuplicateAttractionTicketForSameCustomerAndDay() {
        when(jdbc.queryForList(contains("FOR UPDATE"), eq(7L)))
                .thenReturn(List.of(Map.of("id", 7L)));
        when(jdbc.queryForList(contains("FROM bookings"), eq(7L), eq("attraction")))
                .thenReturn(List.of(Map.of(
                        "title", "Museum of Cairo",
                        "date", Timestamp.valueOf("2026-11-10 00:00:00"),
                        "end_date", "2026-11-11T00:00:00")));

        ResponseEntity<?> response = controller.createBooking(Map.of(
                "type", "attraction",
                "title", "Museum of Cairo",
                "subtitle", "Cairo",
                "date", "2026-11-10T12:00:00Z",
                "end_date", "2026-11-11T12:00:00Z",
                "price", 25), authenticatedRequest());

        assertEquals(409, response.getStatusCode().value());
        assertEquals(Map.of("message", "BOOKING_SCHEDULE_CONFLICT"), response.getBody());
    }

        @Test
        void updateProfileChangesNameAndPhone() {
                MockHttpServletRequest request = authenticatedRequest();
                when(jdbc.update("UPDATE users SET name = ?, phone = ?, updated_at = NOW() WHERE id = ?",
                                "Updated User", "987654321", 7L)).thenReturn(1);
                when(jdbc.queryForMap(contains("LEFT JOIN partners"), eq(7L)))
                                .thenReturn(new java.util.LinkedHashMap<>(Map.of(
                                                "id", 7L,
                                                "name", "Updated User",
                                                "email", "user@example.com",
                                                "phone", "987654321",
                                                "role", "customer")));

                ResponseEntity<?> response = controller.updateProfile("Updated User", "987654321", null, request);

                assertEquals(200, response.getStatusCode().value());
                Map<?, ?> responseBody = (Map<?, ?>) response.getBody();
                assertNotNull(responseBody);
                Map<?, ?> user = (Map<?, ?>) responseBody.get("user");
                assertNotNull(user);
                assertEquals("Updated User", user.get("name"));
        }

        @Test
        void changePasswordRejectsAnIncorrectCurrentPassword() {
                when(jdbc.queryForList("SELECT password FROM users WHERE id = ?", 7L))
                                .thenReturn(List.of(Map.of("password", new BCryptPasswordEncoder().encode("correct-password"))));
                MockHttpServletRequest request = authenticatedRequest();

                ResponseEntity<?> response = controller.changePassword(Map.of(
                                "current_password", "wrong-password",
                                "password", "new-password",
                                "password_confirmation", "new-password"), request);

                assertEquals(422, response.getStatusCode().value());
        Map<?, ?> responseBody = (Map<?, ?>) response.getBody();
        assertNotNull(responseBody);
        assertTrue(responseBody.containsKey("errors"));
        }

        private static MockHttpServletRequest authenticatedRequest() {
                MockHttpServletRequest request = new MockHttpServletRequest();
                request.setAttribute("authUserId", 7L);
                return request;
        }
}