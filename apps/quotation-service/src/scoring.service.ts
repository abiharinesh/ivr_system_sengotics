import { Injectable } from '@nestjs/common'

export interface QuotationScoreInput {
    pricePerLight: number
    installationCost: number
    quantity: number
    deliveryDays: number
    warrantyMonths: number
    sellerRating: number
    experienceYears: number
}

export interface ScoreWeights {
    price: number
    warranty: number
    delivery: number
    rating: number
    experience: number
}

export interface ScoredQuotation {
    finalScore: number
    totalCost: number
    breakdown: {
        price: number
        warranty: number
        delivery: number
        rating: number
        experience: number
    }
}

const DEFAULT_WEIGHTS: ScoreWeights = {
    price: 40,
    warranty: 20,
    delivery: 15,
    rating: 15,
    experience: 10,
}

@Injectable()
export class ScoringService {
    getDefaultWeights(): ScoreWeights {
        return { ...DEFAULT_WEIGHTS }
    }

    scoreQuotation(input: QuotationScoreInput, context: {
        minTotalCost: number
        maxTotalCost: number
        minDeliveryDays: number
        maxDeliveryDays: number
        maxWarrantyMonths: number
        maxSellerRating: number
        maxExperienceYears: number
    }, weights: ScoreWeights = DEFAULT_WEIGHTS): ScoredQuotation {
        const totalCost = (input.pricePerLight * input.quantity) + input.installationCost
        const priceScore = this.inverseNormalize(totalCost, context.minTotalCost, context.maxTotalCost)
        const deliveryScore = this.inverseNormalize(input.deliveryDays, context.minDeliveryDays, context.maxDeliveryDays)
        const warrantyScore = this.normalize(input.warrantyMonths, 0, Math.max(1, context.maxWarrantyMonths))
        const ratingScore = this.normalize(input.sellerRating, 0, Math.max(1, context.maxSellerRating))
        const experienceScore = this.normalize(input.experienceYears, 0, Math.max(1, context.maxExperienceYears))

        const weightedPrice = priceScore * (weights.price / 100)
        const weightedWarranty = warrantyScore * (weights.warranty / 100)
        const weightedDelivery = deliveryScore * (weights.delivery / 100)
        const weightedRating = ratingScore * (weights.rating / 100)
        const weightedExperience = experienceScore * (weights.experience / 100)

        const finalScore = Number((weightedPrice + weightedWarranty + weightedDelivery + weightedRating + weightedExperience).toFixed(4))

        return {
            finalScore,
            totalCost,
            breakdown: {
                price: Number(weightedPrice.toFixed(4)),
                warranty: Number(weightedWarranty.toFixed(4)),
                delivery: Number(weightedDelivery.toFixed(4)),
                rating: Number(weightedRating.toFixed(4)),
                experience: Number(weightedExperience.toFixed(4)),
            }
        }
    }

    private normalize(value: number, min: number, max: number): number {
        if (!Number.isFinite(value)) return 0
        if (max <= min) return 100
        const normalized = ((value - min) / (max - min)) * 100
        return this.clamp(normalized)
    }

    private inverseNormalize(value: number, min: number, max: number): number {
        if (!Number.isFinite(value)) return 0
        if (max <= min) return 100
        const normalized = (1 - ((value - min) / (max - min))) * 100
        return this.clamp(normalized)
    }

    private clamp(value: number): number {
        if (value < 0) return 0
        if (value > 100) return 100
        return Number(value.toFixed(4))
    }
}
