package com.yourcompany.ats.evaluation.builder;

import com.yourcompany.ats.evaluation.dto.CandidateProfileDTO;
import com.yourcompany.ats.evaluation.dto.CandidateResponseDTO;
import com.yourcompany.ats.evaluation.dto.ExtractionResultDTO;
import com.yourcompany.ats.evaluation.dto.ScoreResultDTO;

/**
 * Assembles the single "everything about this candidate for this job" view.
 * Extraction and score are optional - a candidate may exist before either
 * step has run - so this builder tolerates nulls instead of the caller
 * having to null-check three services inline.
 */
public class CandidateProfileBuilder {

    private CandidateResponseDTO candidate;
    private ExtractionResultDTO extraction;
    private ScoreResultDTO score;

    public static CandidateProfileBuilder forCandidate(CandidateResponseDTO candidate) {
        CandidateProfileBuilder builder = new CandidateProfileBuilder();
        builder.candidate = candidate;
        return builder;
    }

    public CandidateProfileBuilder withExtraction(ExtractionResultDTO extraction) {
        this.extraction = extraction;
        return this;
    }

    public CandidateProfileBuilder withScore(ScoreResultDTO score) {
        this.score = score;
        return this;
    }

    public CandidateProfileDTO build() {
        return CandidateProfileDTO.builder()
                .candidate(candidate)
                .extraction(extraction)
                .score(score)
                .build();
    }
}



package com.yourcompany.ats.evaluation.builder;

import com.yourcompany.ats.evaluation.model.JobExtractionResult;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Builds a JobExtractionResult step by step as the AI parser streams back
 * pieces of the CV (skills first, then experience, then education...).
 * Keeps the parsing service from having to juggle a half-built entity by hand.
 */
public class ExtractionResultBuilder {

    private String jobOpeningId;
    private String candidateId;
    private final List<String> skills = new ArrayList<>();
    private final List<Map<String, Object>> experienceEntries = new ArrayList<>();
    private final List<Map<String, Object>> education = new ArrayList<>();
    private final List<Map<String, Object>> certifications = new ArrayList<>();
    private Integer gradYear;
    private Integer totalYearsExperience;
    private Integer relevantYearsExperience;

    public static ExtractionResultBuilder forJobAndCandidate(String jobOpeningId, String candidateId) {
        ExtractionResultBuilder builder = new ExtractionResultBuilder();
        builder.jobOpeningId = jobOpeningId;
        builder.candidateId = candidateId;
        return builder;
    }

    public ExtractionResultBuilder addSkills(List<String> parsedSkills) {
        if (parsedSkills != null) {
            this.skills.addAll(parsedSkills);
        }
        return this;
    }

    public ExtractionResultBuilder addExperienceEntry(Map<String, Object> entry) {
        if (entry != null) {
            this.experienceEntries.add(entry);
        }
        return this;
    }

    public ExtractionResultBuilder addEducationEntry(Map<String, Object> entry) {
        if (entry != null) {
            this.education.add(entry);
        }
        return this;
    }

    public ExtractionResultBuilder addCertification(Map<String, Object> certification) {
        if (certification != null) {
            this.certifications.add(certification);
        }
        return this;
    }

    public ExtractionResultBuilder withGradYear(Integer gradYear) {
        this.gradYear = gradYear;
        return this;
    }

    public ExtractionResultBuilder withExperienceYears(Integer total, Integer relevant) {
        this.totalYearsExperience = total;
        this.relevantYearsExperience = relevant;
        return this;
    }

    public JobExtractionResult build() {
        return JobExtractionResult.builder()
                .id(UUID.randomUUID().toString())
                .jobOpeningId(jobOpeningId)
                .candidateId(candidateId)
                .extractedAt(LocalDateTime.now())
                .skills(skills)
                .experienceEntries(experienceEntries)
                .education(education)
                .certifications(certifications)
                .gradYear(gradYear)
                .totalYearsExperience(totalYearsExperience)
                .relevantYearsExperience(relevantYearsExperience)
                .build();
    }
}




package com.yourcompany.ats.evaluation.builder;

import com.yourcompany.ats.evaluation.model.ScoreResult;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Builds a ScoreResult incrementally as the ScoringEngine walks through
 * mandatory skills, preferred skills, experience, education, etc.
 * Each "add" call represents one requirement being checked off (or not).
 */
public class ScoreResultBuilder {

    private final String jobOpeningId;
    private final String candidateId;
    private final List<Map<String, Object>> matchedItems = new ArrayList<>();
    private final List<Map<String, Object>> missingItems = new ArrayList<>();
    private Integer totalExperienceYears;
    private Integer relevantExperienceYears;

    // running weighted totals, used to compute the final percentage
    private double earnedWeight = 0.0;
    private double possibleWeight = 0.0;

    private ScoreResultBuilder(String jobOpeningId, String candidateId) {
        this.jobOpeningId = jobOpeningId;
        this.candidateId = candidateId;
    }

    public static ScoreResultBuilder forJobAndCandidate(String jobOpeningId, String candidateId) {
        return new ScoreResultBuilder(jobOpeningId, candidateId);
    }

    public ScoreResultBuilder addMatch(String requirementType, String value, double weight) {
        matchedItems.add(Map.of(
                "type", requirementType,
                "value", value,
                "weight", weight
        ));
        earnedWeight += weight;
        possibleWeight += weight;
        return this;
    }

    public ScoreResultBuilder addMissing(String requirementType, String value, double weight) {
        missingItems.add(Map.of(
                "type", requirementType,
                "value", value,
                "weight", weight
        ));
        possibleWeight += weight;
        return this;
    }

    public ScoreResultBuilder withExperienceYears(Integer total, Integer relevant) {
        this.totalExperienceYears = total;
        this.relevantExperienceYears = relevant;
        return this;
    }

    public ScoreResult build() {
        BigDecimal score = possibleWeight == 0
                ? BigDecimal.ZERO
                : BigDecimal.valueOf(earnedWeight / possibleWeight * 100)
                    .setScale(2, RoundingMode.HALF_UP);

        return ScoreResult.builder()
                .id(UUID.randomUUID().toString())
                .jobOpeningId(jobOpeningId)
                .candidateId(candidateId)
                .score(score)
                .matchedItems(matchedItems)
                .missingItems(missingItems)
                .totalExperienceYears(totalExperienceYears)
                .relevantExperienceYears(relevantExperienceYears)
                .computedAt(LocalDateTime.now())
                .build();
    }
}
