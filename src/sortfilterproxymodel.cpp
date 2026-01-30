/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the examples of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** BSD License Usage
** Alternatively, you may use this file under the terms of the BSD license
** as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of The Qt Company Ltd nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "sortfilterproxymodel.h"
#include "logger.h"
#include <QtQml>

SortFilterProxyModel::SortFilterProxyModel(QObject *parent) : QSortFilterProxyModel(parent), m_complete(false)
{
    connect(this, &QSortFilterProxyModel::rowsInserted, this, &SortFilterProxyModel::countChanged);
    connect(this, &QSortFilterProxyModel::rowsRemoved, this, &SortFilterProxyModel::countChanged);
}

int SortFilterProxyModel::count() const
{
    return rowCount();
}

QObject *SortFilterProxyModel::source() const
{
    return sourceModel();
}

void SortFilterProxyModel::setSource(QObject *source)
{
    setSourceModel(qobject_cast<QAbstractItemModel *>(source));
}

QByteArray SortFilterProxyModel::sortRole() const
{
    return m_sortRole;
}

void SortFilterProxyModel::setSortRole(const QByteArray &role)
{
    if (m_sortRole != role) {
        m_sortRole = role;
        if (m_complete) {
            int roleKeyValue = roleKey(role);
            if (roleKeyValue >= 0) {
                QSortFilterProxyModel::setSortRole(roleKeyValue);
                // Trigger sort when role changes (so first click on a column header sorts immediately)
                QSortFilterProxyModel::sort(0, sortOrder());
            }
        }
    }
}

Qt::SortOrder SortFilterProxyModel::sortOrder() const
{
    return QSortFilterProxyModel::sortOrder();
}

void SortFilterProxyModel::setSortOrder(Qt::SortOrder order)
{
    if (m_complete) {
        // Ensure sortRole is set before sorting
        if (!m_sortRole.isEmpty()) {
            int role = roleKey(m_sortRole);
            if (role >= 0) {
                QSortFilterProxyModel::setSortRole(role);
            }
        }
        // Only sort if order is valid
        if (order == Qt::AscendingOrder || order == Qt::DescendingOrder) {
            QSortFilterProxyModel::sort(0, order);  // Column 0 for role-based models
        }
    }
}

Qt::CaseSensitivity SortFilterProxyModel::sortCaseSensitivity() const
{
    return QSortFilterProxyModel::sortCaseSensitivity();
}

void SortFilterProxyModel::setSortCaseSensitivity(Qt::CaseSensitivity caseSensitivity)
{
    QSortFilterProxyModel::setSortCaseSensitivity(caseSensitivity);
}

QByteArray SortFilterProxyModel::filterRole() const
{
    return m_filterRole;
}

void SortFilterProxyModel::setFilterRole(const QByteArray &role)
{
    if (m_filterRole != role) {
        m_filterRole = role;
        if (m_complete)
            QSortFilterProxyModel::setFilterRole(roleKey(role));
    }
}

QString SortFilterProxyModel::filterString() const
{
    return filterRegExp().pattern();
}

void SortFilterProxyModel::setFilterString(const QString &filter)
{
    setFilterRegExp(QRegExp(filter, filterCaseSensitivity(), static_cast<QRegExp::PatternSyntax>(filterSyntax())));
}

SortFilterProxyModel::FilterSyntax SortFilterProxyModel::filterSyntax() const
{
    return static_cast<FilterSyntax>(filterRegExp().patternSyntax());
}

void SortFilterProxyModel::setFilterSyntax(SortFilterProxyModel::FilterSyntax syntax)
{
    setFilterRegExp(QRegExp(filterString(), filterCaseSensitivity(), static_cast<QRegExp::PatternSyntax>(syntax)));
}

Qt::CaseSensitivity SortFilterProxyModel::filterCaseSensitivity() const
{
    return QSortFilterProxyModel::filterCaseSensitivity();
}

void SortFilterProxyModel::setFilterCaseSensitivity(Qt::CaseSensitivity caseSensitivity)
{
    QSortFilterProxyModel::setFilterCaseSensitivity(caseSensitivity);
}

QString SortFilterProxyModel::renderVersionFilter() const
{
    return m_renderVersionFilter;
}

void SortFilterProxyModel::setRenderVersionFilter(const QString &version)
{
    if (m_renderVersionFilter != version) {
        DEBUG_LOG("SortFilterProxyModel") << "setRenderVersionFilter - Setting filter to:" << version;
        m_renderVersionFilter = version;
        emit renderVersionFilterChanged();
        invalidateFilter();  // Trigger re-filtering when version changes
        DEBUG_LOG("SortFilterProxyModel") << "setRenderVersionFilter - Filter invalidated, row count:" << rowCount();
    }
}

void SortFilterProxyModel::sort(int column, Qt::SortOrder order)
{
    Q_UNUSED(column);  // Column is always 0 for role-based models
    if (m_complete) {
        // Ensure sortRole is set for role-based models
        if (!m_sortRole.isEmpty()) {
            int role = roleKey(m_sortRole);
            if (role >= 0) {
                QSortFilterProxyModel::setSortRole(role);
            }
        }
        QSortFilterProxyModel::sort(0, order);  // Column 0 for role-based models
    }
}

/**
 * @brief Get row data as JavaScript object (used by QML)
 * Row index is in proxy model coordinates, so it works correctly after sorting/filtering.
 */
QJSValue SortFilterProxyModel::get(int idx) const
{
    QJSEngine *engine = qmlEngine(this);
    QJSValue value = engine->newObject();
    if (idx >= 0 && idx < count()) {
        QHash<int, QByteArray> roles = roleNames();
        for (auto it = roles.cbegin(), end = roles.cend(); it != end; ++it) {
            QVariant variantData = data(index(idx, 0), it.key());
            value.setProperty(QString::fromUtf8(it.value()), variantData.toString());
        }
    }
    return value;
}

int SortFilterProxyModel::mapProxyRowToSource(int proxyRow) const
{
    if (proxyRow < 0 || proxyRow >= rowCount()) {
        return -1;
    }
    QModelIndex proxyIndex = index(proxyRow, 0);
    if (!proxyIndex.isValid()) {
        return -1;
    }
    QModelIndex sourceIndex = mapToSource(proxyIndex);
    return sourceIndex.isValid() ? sourceIndex.row() : -1;
}

void SortFilterProxyModel::classBegin()
{
}

void SortFilterProxyModel::componentComplete()
{
    m_complete = true;
    if (!m_sortRole.isEmpty())
        QSortFilterProxyModel::setSortRole(roleKey(m_sortRole));
    if (!m_filterRole.isEmpty())
        QSortFilterProxyModel::setFilterRole(roleKey(m_filterRole));
}

int SortFilterProxyModel::roleKey(const QByteArray &role) const
{
    return roleNames().key(role, -1);
}

QHash<int, QByteArray> SortFilterProxyModel::roleNames() const
{
    if (QAbstractItemModel *source = sourceModel())
        return source->roleNames();
    return QHash<int, QByteArray>();
}

/**
 * @brief Determine if row should be included after filtering
 * If filterRole is empty, searches all roles (global search).
 * Also applies render version filtering if renderVersionFilter is set.
 */
bool SortFilterProxyModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    QAbstractItemModel *model = sourceModel();
    QModelIndex sourceIndex = model->index(sourceRow, 0, sourceParent);
    if (!sourceIndex.isValid())
        return true;
    
    // Apply render version filtering if set
    if (!m_renderVersionFilter.isEmpty()) {
        // Get renderVersions field (column 11) - check if it contains the selected render version
        QHash<int, QByteArray> roles = roleNames();
        int renderVersionsRole = roleKey("renderVersions");
        if (renderVersionsRole >= 0) {
            QString renderVersions = model->data(sourceIndex, renderVersionsRole).toString();
            // renderVersions is a comma-separated list (e.g., "version1,version2")
            // If renderVersions is empty, this test doesn't belong to any render version, so filter it out
            if (renderVersions.isEmpty()) {
                DEBUG_LOG("SortFilterProxyModel") << "Filtering out row" << sourceRow 
                         << "- renderVersions is empty (test not yet associated with a render version)";
                return false;  // Filter out rows with empty renderVersions when a specific version is selected
            }
            
            // Check if the selected render version is in the list
            QStringList versionList = renderVersions.split(',', QString::SkipEmptyParts);
            bool found = false;
            for (const QString &version : versionList) {
                QString trimmedVersion = version.trimmed();
                if (trimmedVersion.compare(m_renderVersionFilter, Qt::CaseInsensitive) == 0) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                DEBUG_LOG("SortFilterProxyModel") << "Filtering out row" << sourceRow 
                         << "- renderVersions:" << renderVersions 
                         << "does not contain filter:" << m_renderVersionFilter;
                return false;  // Filter out rows that don't match the selected render version
            } else {
                DEBUG_LOG("SortFilterProxyModel") << "Row" << sourceRow 
                         << "matches filter" << m_renderVersionFilter 
                         << "- renderVersions:" << renderVersions;
            }
        } else {
            // Fallback: If renderVersions role not available, try thumbnailPath (backward compatibility)
            int thumbnailPathRole = roleKey("thumbnailPath");
            if (thumbnailPathRole >= 0) {
                QString thumbnailPath = model->data(sourceIndex, thumbnailPathRole).toString();
                // Check if thumbnailPath contains the render version filter string
                if (!thumbnailPath.contains(m_renderVersionFilter, Qt::CaseInsensitive)) {
                    return false;  // Filter out rows that don't match the selected render version
                }
            } else {
                // If we can't get either field, filter out this row
                return false;
            }
        }
    }
    
    // Apply regular filterString/filterRole filtering (if set)
    QRegExp rx = filterRegExp();
    if (rx.isEmpty())
        return true;  // No regular filter, only render version filter was applied
    
    // If filterRole is empty, search across all roles (global search)
    if (filterRole().isEmpty()) {
        QHash<int, QByteArray> roles = roleNames();
        for (auto it = roles.cbegin(), end = roles.cend(); it != end; ++it) {
            QString key = model->data(sourceIndex, it.key()).toString();
            if (key.contains(rx))
                return true;
        }
        return false;
    }
    
    // If filterRole is set, only search that specific role
    QString key = model->data(sourceIndex, roleKey(filterRole())).toString();
    return key.contains(rx);
}
