import _ from 'lodash';
import { categoryFieldNameOfCategoryName } from './utils';

export const activeCategoryFilters = (docFilterCriteria) => (_(docFilterCriteria.category).
        toPairs().
        filter((([key, value]) => value)). // eslint-disable-line no-unused-vars
        map(([key]) => categoryFieldNameOfCategoryName(key)).
        value());

export const activeTagFilters = (docFilterCriteria, appliedFunction) => (_(docFilterCriteria.tag).
        toPairs().
        filter((([key, value]) => value)). // eslint-disable-line no-unused-vars
        map(([key]) => appliedFunction ? appliedFunction(key) : key). // eslint-disable-line no-confusing-arrow
        value());
